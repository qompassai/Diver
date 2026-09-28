-- lua/dev/browser/cdp/init.lua
-- CDP connection manager: HTTP discovery, WebSocket transport, flat-mode
-- attach, and frame routing to per-session state.
-- Plain words: given a host and port, this finds the browser's debugger
-- URL (used verbatim, never reconstructed), opens one WebSocket, proves
-- it is really CDP via Browser.getVersion, attaches to a page target, and
-- hands you a connection whose target session carries the sessionId.
-- Copyright (C) 2026 Qompass AI. All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
---@module 'dev.browser.cdp'

local session = require('dev.browser.cdp.session')
local domains = require('dev.browser.cdp.domains')
local security = require('dev.browser.cdp.security')

local M = {}

local DISCOVERY_TIMEOUT_MS = 5000
local PUMP_INTERVAL_MS = 1000 -- timeout sweep cadence for pending requests
local PORT_MIN = 1
local PORT_MAX = 65535

---@class CdpDiscoverOpts
---@field host? string default '127.0.0.1'
---@field port? integer default 9222
---@field http? table shared helper (injected in tests)
---@field timeout_ms? integer
---@field json_decode? fun(text: string): table

---@class CdpDiscovery
---@field host string
---@field port integer
---@field browser_ws_url string verbatim webSocketDebuggerUrl from /json/version
---@field browser_name string|nil
---@field protocol_version string|nil
---@field targets table raw /json/list array
---@field pages table[] targets with type == 'page' and a string id

---@class CdpConnectOpts : CdpDiscoverOpts
---@field target_id? string page target to attach; defaults to first page
---@field ws_new? fun(opts: table): table|nil, string|nil websocket factory (injected in tests)
---@field clock? fun(): integer
---@field json_encode? fun(value: table): string
---@field on_connected? fun(conn: CdpConnection)
---@field on_error? fun(err: string)

---@class CdpConnection
---@field host string
---@field port integer
---@field browser_ws_url string
---@field discovery CdpDiscovery
---@field browser_session table browser-level session (no sessionId)
---@field target_session table|nil attached page session
---@field target_session_id string|nil
---@field target_id string|nil
---@field target_url string|nil page URL, for confirmation prompts
---@field closed boolean

---Lazy require of the shared HTTP helper (sibling track owns it).
---@return table|nil http
---@return string|nil err
local function get_http()
    local ok, mod = pcall(require, 'dev.browser.http')
    if not ok then
        return nil, 'shared HTTP helper unavailable (dev.browser.http): ' .. tostring(mod)
    end
    if type(mod) ~= 'table' or type(mod.request) ~= 'function' then
        return nil, 'shared HTTP helper has no request() function'
    end
    return mod
end

---@param text string
---@param json_decode fun(text: string): table|nil
---@return table|nil value
---@return string|nil err
local function decode_json(text, json_decode)
    if type(text) ~= 'string' or text == '' then
        return nil, 'empty body'
    end
    local ok, value = pcall(json_decode, text)
    if not ok then
        return nil, 'invalid JSON: ' .. tostring(value)
    end
    return value
end

---@param opts CdpDiscoverOpts
---@return fun(text: string): table|nil decoder
local function pick_decoder(opts)
    if opts.json_decode ~= nil then
        return opts.json_decode
    end
    return function(text)
        -- selene: allow(global_usage)
        return rawget(_G, 'vim').json.decode(text)
    end
end

---@param opts CdpDiscoverOpts
---@param path string
---@return table|nil res
---@return string|nil err
local function discovery_get(opts, path, http, timeout_ms)
    local res, err = http.request({
        host = opts.host or '127.0.0.1',
        port = opts.port or 9222,
        method = 'GET',
        path = path,
        timeout_ms = timeout_ms,
    })
    if res == nil then
        return nil, 'discovery ' .. path .. ' failed: ' .. tostring(err)
    end
    return res
end

---Probe /json/version and /json/list. A 404 or a non-JSON body means
---"not a CDP endpoint", not a retryable error.
---@param opts CdpDiscoverOpts
---@return CdpDiscovery|nil
---@return string|nil err
function M.discover(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    local host = opts.host or '127.0.0.1'
    local port = opts.port or 9222
    local ok, herr = security.check_host(host)
    if not ok then
        return nil, herr
    end
    if type(port) ~= 'number' or port ~= math.floor(port) or port < PORT_MIN or port > PORT_MAX then
        return nil, 'port must be an integer 1..65535'
    end
    local http = opts.http
    if http == nil then
        local h, herr2 = get_http()
        if h == nil then
            return nil, herr2
        end
        http = h
    end
    local timeout_ms = opts.timeout_ms or DISCOVERY_TIMEOUT_MS
    local decode = pick_decoder(opts)
    local res, err = discovery_get({ host = host, port = port }, '/json/version', http, timeout_ms)
    if res == nil then
        return nil, err
    end
    if res.status ~= 200 then
        return nil, 'not a CDP endpoint: /json/version -> HTTP ' .. tostring(res.status)
    end
    local version, derr = decode_json(res.body, decode)
    if version == nil or type(version) ~= 'table' then
        return nil, 'not a CDP endpoint: /json/version is not JSON (' .. tostring(derr) .. ')'
    end
    local ws_url = version.webSocketDebuggerUrl
    if type(ws_url) ~= 'string' or ws_url == '' then
        return nil, 'not a CDP endpoint: /json/version missing webSocketDebuggerUrl'
    end
    local lres, lerr = discovery_get({ host = host, port = port }, '/json/list', http, timeout_ms)
    if lres == nil then
        return nil, lerr
    end
    if lres.status ~= 200 then
        return nil, 'discovery /json/list -> HTTP ' .. tostring(lres.status)
    end
    local targets, terr = decode_json(lres.body, decode)
    if type(targets) ~= 'table' then
        return nil, 'discovery /json/list is not a JSON array (' .. tostring(terr) .. ')'
    end
    local pages = {}
    for _, target_info in ipairs(targets) do
        local is_page = type(target_info) == 'table' and target_info.type == 'page'
        if is_page and type(target_info.id) == 'string' then
            pages[#pages + 1] = target_info
        end
    end
    return {
        host = host,
        port = port,
        browser_ws_url = ws_url, -- verbatim from discovery; never reconstructed
        browser_name = version.Browser,
        protocol_version = version['Protocol-Version'],
        targets = targets,
        pages = pages,
    }
end

---Default websocket factory over ai.websocket.client (reconnect off:
---a dropped CDP socket invalidates session state, so reconnect is
---explicit, not automatic).
---@param ws_opts table { url, on_message, on_connect, on_disconnect, on_error }
---@return table|nil ws
---@return string|nil err
local function default_ws_new(ws_opts)
    local ok, mod = pcall(require, 'ai.websocket.client')
    if not ok then
        return nil, 'websocket client unavailable: ' .. tostring(mod)
    end
    local client = mod.WebsocketClient.new({
        connect_addr = ws_opts.url,
        on_message = function(_, text)
            ws_opts.on_message(text)
        end,
        on_connect = function(_)
            ws_opts.on_connect()
        end,
        on_disconnect = function(_)
            ws_opts.on_disconnect()
        end,
        on_error = function(_, err)
            ws_opts.on_error(err)
        end,
        reconnect = false,
    })
    client:try_connect()
    return client
end

---Sweep both sessions' pending requests for timeouts.
---@param conn CdpConnection
---@param now_ms integer
function M.pump(conn, now_ms)
    assert(type(conn) == 'table', 'conn must be a table')
    assert(type(now_ms) == 'number', 'now_ms must be a number')
    if conn.browser_session ~= nil then
        conn.browser_session:check_timeouts(now_ms)
    end
    if conn.target_session ~= nil then
        conn.target_session:check_timeouts(now_ms)
    end
end

---@param conn CdpConnection
local function start_pump(conn)
    -- selene: allow(global_usage)
    local v = rawget(_G, 'vim')
    if v == nil or v.uv == nil or v.uv.new_timer == nil then
        return
    end
    local timer = v.uv.new_timer()
    if timer == nil then
        return
    end
    conn._timer = timer
    timer:start(PUMP_INTERVAL_MS, PUMP_INTERVAL_MS, function()
        if conn.closed then
            return
        end
        M.pump(conn, v.uv.now())
    end)
end

---Route one incoming text frame to the right session by sessionId.
---@param conn CdpConnection
---@param text string
function M._on_ws_message(conn, text)
    if conn.closed then
        return
    end
    local decode = conn._json_decode
    local ok, msg = pcall(decode, text)
    if not ok or type(msg) ~= 'table' then
        conn._on_error('ignoring malformed frame: ' .. tostring(msg))
        return
    end
    local target_session = conn.browser_session
    local session_id = msg.sessionId
    if session_id ~= nil then
        if conn.target_session ~= nil and session_id == conn.target_session_id then
            target_session = conn.target_session
        else
            conn._on_error('ignoring frame for unknown sessionId')
            return
        end
    end
    target_session:handle_message(msg)
end

---Pick the page target and attach in flat mode.
---@param conn CdpConnection
---@param opts CdpConnectOpts
function M._attach(conn, opts)
    local target_id = opts.target_id
    if target_id == nil then
        local first_page = conn.discovery.pages[1]
        if first_page == nil then
            conn._on_error('no page targets to attach')
            M.close(conn)
            return
        end
        target_id = first_page.id
    else
        local known = false
        for _, page_info in ipairs(conn.discovery.pages) do
            if page_info.id == target_id then
                known = true
                break
            end
        end
        if not known then
            conn._on_error('unknown target id: ' .. tostring(target_id))
            M.close(conn)
            return
        end
    end
    domains.target.attach_to_target(conn.browser_session, target_id, function(result, err)
        if conn.closed then
            return
        end
        if err ~= nil or type(result) ~= 'table' or type(result.sessionId) ~= 'string' then
            conn._on_error('attach failed: ' .. tostring(err))
            M.close(conn)
            return
        end
        local target_session = session.new({
            session_id = result.sessionId,
            timeout_ms = opts.timeout_ms,
            json_encode = conn._json_encode,
            json_decode = conn._json_decode,
            clock = opts.clock,
            on_error = conn._on_error,
        })
        target_session:set_transport(conn._transport)
        conn.target_session = target_session
        conn.target_session_id = result.sessionId
        conn.target_id = target_id
        for _, page_info in ipairs(conn.discovery.pages) do
            if page_info.id == target_id then
                conn.target_url = page_info.url
                break
            end
        end
        if opts.on_connected ~= nil then
            opts.on_connected(conn)
        end
    end)
end

---Runs on websocket connect: confirm a real CDP endpoint, then attach.
---@param conn CdpConnection
---@param opts CdpConnectOpts
function M._on_ws_connect(conn, opts)
    if conn.closed then
        return
    end
    domains.browser.get_version(conn.browser_session, function(result, err)
        if conn.closed then
            return
        end
        if err ~= nil or type(result) ~= 'table' then
            conn._on_error('not a CDP endpoint: Browser.getVersion failed: ' .. tostring(err))
            M.close(conn)
            return
        end
        M._attach(conn, opts)
    end)
end

---The socket died. Pending requests fail via session close; the
---connection never auto-reconnects (session state would be stale).
---The socket initiated teardown, so M.close must not signal it again.
---@param conn CdpConnection
function M._on_ws_disconnect(conn)
    if conn.closed then
        return
    end
    local err = 'websocket disconnected'
    conn._ws_dead = true
    M.close(conn)
    conn._on_error(err)
end

---Connect: discover, open one websocket to the verbatim debugger URL,
---confirm CDP via Browser.getVersion, attach to a page target in flat
---mode. Async: on_connected fires with the ready connection, on_error
---with failures. Returns the (connecting) connection or nil, err.
---@param opts CdpConnectOpts
---@return CdpConnection|nil conn
---@return string|nil err
function M.connect(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(
        opts.on_connected == nil or type(opts.on_connected) == 'function',
        'on_connected must be a function'
    )
    assert(opts.on_error == nil or type(opts.on_error) == 'function', 'on_error must be a function')
    assert(opts.ws_new == nil or type(opts.ws_new) == 'function', 'ws_new must be a function')
    if opts.target_id ~= nil and (type(opts.target_id) ~= 'string' or opts.target_id == '') then
        return nil, 'target_id must be a non-empty string'
    end
    local on_error = opts.on_error or function() end
    local discovery, derr = M.discover(opts)
    if discovery == nil then
        return nil, derr
    end
    local conn = {
        host = discovery.host,
        port = discovery.port,
        browser_ws_url = discovery.browser_ws_url,
        discovery = discovery,
        closed = false,
        _on_error = on_error,
        _json_decode = pick_decoder(opts),
        _json_encode = opts.json_encode or function(value)
            -- selene: allow(global_usage)
            return rawget(_G, 'vim').json.encode(value)
        end,
    }
    local browser_session = session.new({
        timeout_ms = opts.timeout_ms,
        json_encode = conn._json_encode,
        json_decode = conn._json_decode,
        clock = opts.clock,
        on_error = on_error,
    })
    conn.browser_session = browser_session
    local transport = {}
    function transport.send(text)
        if conn.ws == nil then
            return nil, 'websocket not connected yet'
        end
        return conn.ws:try_send_data(text)
    end
    conn._transport = transport
    browser_session:set_transport(transport)
    local ws_new = opts.ws_new or default_ws_new
    local ws, werr = ws_new({
        url = discovery.browser_ws_url,
        on_message = function(text)
            M._on_ws_message(conn, text)
        end,
        on_connect = function()
            M._on_ws_connect(conn, opts)
        end,
        on_disconnect = function()
            M._on_ws_disconnect(conn)
        end,
        on_error = function(err)
            on_error(err)
        end,
    })
    if ws == nil then
        return nil, werr
    end
    conn.ws = ws
    start_pump(conn)
    return conn
end

---Idempotent teardown: stop the timeout pump, fail pending requests,
---close the socket exactly once, kill a launched child browser if any.
---@param conn CdpConnection
function M.close(conn)
    assert(type(conn) == 'table', 'conn must be a table')
    if conn.closed then
        return
    end
    conn.closed = true
    if conn._timer ~= nil then
        local timer = conn._timer
        conn._timer = nil
        pcall(function()
            timer:stop()
            timer:close()
        end)
    end
    if conn.browser_session ~= nil then
        conn.browser_session:close()
    end
    if conn.target_session ~= nil then
        conn.target_session:close()
    end
    if conn.ws ~= nil then
        local ws = conn.ws
        conn.ws = nil
        if not conn._ws_dead then
            pcall(function()
                ws:try_disconnect()
            end)
        end
    end
    if conn._child ~= nil then
        local child = conn._child
        conn._child = nil
        pcall(function()
            child:kill('sigterm')
        end)
    end
    if conn._profile ~= nil then
        local profile = conn._profile
        conn._profile = nil
        pcall(security.remove_temp_profile, profile)
    end
end

return M
