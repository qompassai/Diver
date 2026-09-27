-- lua/dev/browser/cdp/actions.lua
-- The seven MVP browser actions. Thin orchestration over domains plus
-- the security policy; rendering lives in small bounded helpers.
-- Plain words: open/attach/navigate/evaluate/screenshot/console/network.
-- Every privileged step (attach, eval) demands explicit confirmation;
-- evaluation never runs from an autocmd or an untrusted buffer.
-- Copyright (C) 2026 Qompass AI. All rights reserved.
-- SPDX-License-Identifier: Apache-2.0
---@module 'dev.browser.cdp.actions'

local cdp = require('dev.browser.cdp')
local domains = require('dev.browser.cdp.domains')
local security = require('dev.browser.cdp.security')

local M = {}

local DEFAULT_PORT = 9222
local OPEN_POLL_ATTEMPTS_MAX = 25
local OPEN_POLL_INTERVAL_MS = 200
local RING_CAPACITY_DEFAULT = 500
local NETLOG_CAPACITY_DEFAULT = 500
local ENTRY_PREVIEW_MAX = 200 -- chars of a console arg shown per line
local CONSOLE_ARGS_MAX = 32 -- console args stored per entry
local STORED_TEXT_MAX = 4096 -- chars stored per text-ish field
local SCREENSHOT_DATA_MAX = 16777216 -- 16 MiB of base64 image data
local CHROME_BINS = { 'google-chrome', 'chromium', 'chromium-browser' }

---@alias CdpActionCallback fun(err: string|nil, result: any)

---@param url string|nil
---@return boolean
function M.is_web_url(url)
    return type(url) == 'string' and url:match('^https?://[^%s]+$') ~= nil
end

---Bounded ring buffer for console/log entries. Non-table pushes are
---ignored; oldest entries drop off past capacity.
---@param capacity? integer
function M.new_ring(capacity)
    capacity = capacity or RING_CAPACITY_DEFAULT
    assert(type(capacity) == 'number' and capacity >= 1, 'capacity must be positive')
    local items = {}
    local ring = {}
    ---@param entry table
    function ring:push(entry)
        if type(entry) ~= 'table' then
            return
        end
        items[#items + 1] = entry
        while #items > capacity do
            table.remove(items, 1)
        end
    end
    ---@return table[] oldest-first copy
    function ring:entries()
        local out = {}
        for i = 1, #items do
            out[i] = items[i]
        end
        return out
    end
    ---@return integer
    function ring:len()
        return #items
    end
    function ring:clear()
        items = {}
    end
    return ring
end

---Bounded network request log, newest last.
---@param capacity? integer
function M.new_network_log(capacity)
    capacity = capacity or NETLOG_CAPACITY_DEFAULT
    assert(type(capacity) == 'number' and capacity >= 1, 'capacity must be positive')
    local items = {}
    local netlog = {}
    ---@param entry table { request_id, method, url, status?, failed? }
    function netlog:push(entry)
        if type(entry) ~= 'table' then
            return
        end
        items[#items + 1] = entry
        while #items > capacity do
            table.remove(items, 1)
        end
    end
    ---@return table[]
    function netlog:entries()
        local out = {}
        for i = 1, #items do
            out[i] = items[i]
        end
        return out
    end
    ---@return integer
    function netlog:len()
        return #items
    end
    function netlog:clear()
        items = {}
    end
    return netlog
end

---@param conn table|nil
---@return table|nil target_session
---@return string|nil err
local function target_session(conn)
    if type(conn) ~= 'table' or conn.closed then
        return nil, 'not connected: run :BrowserAttach or :BrowserOpen first'
    end
    if conn.target_session == nil then
        return nil, 'no attached target yet'
    end
    return conn.target_session
end

---@param name string User autocmd name, e.g. "CdpConsoleMessage"
---@param data table|nil
local function emit(name, data)
    local v = rawget(_G, 'vim')
    if v == nil or v.api == nil or v.api.nvim_exec_autocmds == nil then
        return
    end
    pcall(v.api.nvim_exec_autocmds, 'User', { pattern = name, data = data })
end

---@param message string
---@param level integer|nil
local function notify(message, level)
    local v = rawget(_G, 'vim')
    if v ~= nil and v.notify ~= nil then
        if v.in_fast_event ~= nil and v.in_fast_event() then
            -- CDP response/event callbacks run inside the uv read handler
            -- (fast event context): nvim_notify would raise E5560, and the
            -- raise is swallowed by pcall in session._handle_response, so
            -- the caller's callback would silently never fire. Defer it.
            v.schedule(function()
                v.notify(message, level)
            end)
        else
            v.notify(message, level)
        end
    end
end

---First usable Chrome/Chromium binary on PATH, or nil.
---@return string|nil
function M.find_chrome()
    local v = rawget(_G, 'vim')
    if v == nil or v.fn == nil or v.fn.executable == nil then
        return nil
    end
    for _, bin in ipairs(CHROME_BINS) do
        if v.fn.executable(bin) == 1 then
            return bin
        end
    end
    return nil
end

---@class CdpOpenOpts
---@field port? integer
---@field chrome_bin? string
---@field http? table shared helper (injected in tests)
---@field ws_new? fun(opts: table): table|nil, string|nil

---Launch an isolated headless Chrome (fresh temp --user-data-dir, bound
---to 127.0.0.1) and connect. The child is killed and the temp profile
---removed when the connection closes, so no zombie browser or leftover
---profile survives.
---@param url? string optional start page
---@param opts? CdpOpenOpts
---@param callback? CdpActionCallback
function M.open(url, opts, callback)
    opts = opts or {}
    callback = callback or function() end
    assert(type(opts) == 'table', 'opts must be a table')
    if url ~= nil and not M.is_web_url(url) then
        callback('open: url must be http(s) or omitted', nil)
        return
    end
    local port = opts.port or DEFAULT_PORT
    if type(port) ~= 'number' or port ~= math.floor(port) or port < 1 or port > 65535 then
        callback('open: port must be an integer 1..65535', nil)
        return
    end
    local profile, perr = security.new_temp_profile()
    if profile == nil then
        callback('open: ' .. tostring(perr), nil)
        return
    end
    local bin = opts.chrome_bin or M.find_chrome()
    if bin == nil then
        callback('open: no Chrome/Chromium binary found on PATH', nil)
        return
    end
    local http = opts.http
    if http == nil then
        local hok, hmod = pcall(require, 'dev.browser.http')
        if not hok then
            callback('open: shared HTTP helper unavailable', nil)
            return
        end
        http = hmod
    end
    local busy = cdp.discover({ host = '127.0.0.1', port = port, http = http, timeout_ms = 1000 })
    if busy ~= nil then
        local in_use = 'open: port ' .. tostring(port) .. ' already serves a CDP endpoint'
        callback(in_use .. '; use :BrowserAttach', nil)
        return
    end
    local v = rawget(_G, 'vim')
    local args = {
        bin,
        '--headless=new',
        '--no-first-run',
        '--no-default-browser-check',
        '--remote-debugging-port=' .. tostring(port),
        '--remote-debugging-address=127.0.0.1',
        '--user-data-dir=' .. profile,
        url or 'about:blank',
    }
    local job_ok, job = pcall(v.system, args, { detach = true }, function() end)
    if not job_ok then
        callback('open: failed to launch browser: ' .. tostring(job), nil)
        return
    end
    local attempts = 0
    local timer = v.uv.new_timer()
    timer:start(OPEN_POLL_INTERVAL_MS, OPEN_POLL_INTERVAL_MS, function()
        attempts = attempts + 1
        local probe = { host = '127.0.0.1', port = port, http = http, timeout_ms = 1000 }
        local found = cdp.discover(probe)
        if found ~= nil then
            timer:stop()
            timer:close()
            cdp.connect({
                host = '127.0.0.1',
                port = port,
                http = http,
                ws_new = opts.ws_new,
                on_connected = function(conn)
                    conn._child = job
                    conn._profile = profile
                    callback(nil, conn)
                end,
                on_error = function(err)
                    callback(tostring(err), nil)
                end,
            })
            return
        end
        if attempts >= OPEN_POLL_ATTEMPTS_MAX then
            timer:stop()
            timer:close()
            pcall(function()
                job:kill('sigkill')
            end)
            pcall(security.remove_temp_profile, profile)
            callback('open: browser did not expose CDP in time', nil)
        end
    end)
end

---List page targets for :BrowserAttach's picker.
---@param host? string
---@param port? integer
---@param opts? { http?: table }
---@param callback CdpActionCallback receives page target array
function M.list_targets(host, port, opts, callback)
    opts = opts or {}
    callback = callback or function() end
    local probe = { host = host or '127.0.0.1', port = port or DEFAULT_PORT, http = opts.http }
    local discovery, err = cdp.discover(probe)
    if discovery == nil then
        callback(err, nil)
        return
    end
    callback(nil, discovery.pages)
end

---Attach to one target of a running browser. Demands opts.confirmed;
---the caller shows security.confirm_attach first.
---@param host? string
---@param port? integer
---@param target_id string
---@param opts? { confirmed?: boolean, http?: table, ws_new?: function }
---@param callback? CdpActionCallback
function M.attach(host, port, target_id, opts, callback)
    opts = opts or {}
    callback = callback or function() end
    assert(type(opts) == 'table', 'opts must be a table')
    if type(target_id) ~= 'string' or target_id == '' then
        callback('attach: target_id must be a non-empty string', nil)
        return
    end
    if opts.confirmed ~= true then
        callback('attach: explicit confirmation required (security.confirm_attach)', nil)
        return
    end
    local conn, err = cdp.connect({
        host = host or '127.0.0.1',
        port = port or DEFAULT_PORT,
        target_id = target_id,
        http = opts.http,
        ws_new = opts.ws_new,
        on_connected = function(ready)
            callback(nil, ready)
        end,
        on_error = function(connect_err)
            callback(tostring(connect_err), nil)
        end,
    })
    if conn == nil then
        callback(err, nil)
    end
end

---Navigate the attached page; CDP's errorText becomes the error.
---@param conn table
---@param url string
---@param callback? CdpActionCallback
function M.navigate(conn, url, callback)
    callback = callback or function() end
    if not M.is_web_url(url) then
        callback('navigate: url must be http(s)', nil)
        return
    end
    local ts, terr = target_session(conn)
    if ts == nil then
        callback(terr, nil)
        return
    end
    local id, err = domains.page.navigate(ts, url, function(result, nav_err)
        if nav_err ~= nil then
            callback(nav_err, nil)
            return
        end
        if type(result) == 'table' and result.errorText ~= nil then
            callback('navigate failed: ' .. tostring(result.errorText), nil)
            return
        end
        callback(nil, result)
    end)
    if id == nil then
        callback(err, nil)
    end
end

---Evaluate JS in the page. Per-invocation confirmation showing the exact
---expression and target URL; pass opts.confirmed to skip the prompt
---(only the command layer does this after confirming).
---@param conn table
---@param expression string
---@param opts? { confirmed?: boolean, ui?: table }
---@param callback? CdpActionCallback
function M.eval(conn, expression, opts, callback)
    opts = opts or {}
    callback = callback or function() end
    assert(type(opts) == 'table', 'opts must be a table')
    local ts, terr = target_session(conn)
    if ts == nil then
        callback(terr, nil)
        return
    end
    if type(expression) ~= 'string' or expression == '' then
        callback('eval: expression must be a non-empty string', nil)
        return
    end
    local function run()
        local id, err = domains.runtime.evaluate(ts, expression, function(result, eval_err)
            callback(eval_err, result)
        end)
        if id == nil then
            callback(err, nil)
        end
    end
    if opts.confirmed == true then
        run()
        return
    end
    local target_ref = conn.target_url or tostring(conn.target_id)
    local prompt_opts = { expression = expression, url = target_ref, ui = opts.ui }
    security.confirm_eval(prompt_opts, function(
        allowed,
        reason
    )
        if not allowed then
            callback('eval declined: ' .. tostring(reason), nil)
            return
        end
        run()
    end)
end

---Screenshot the page to a user-chosen path (PNG).
---@param conn table
---@param path? string defaults to a temp file
---@param callback? CdpActionCallback receives the written path
function M.screenshot(conn, path, callback)
    callback = callback or function() end
    local ts, terr = target_session(conn)
    if ts == nil then
        callback(terr, nil)
        return
    end
    local v = rawget(_G, 'vim')
    if path == nil then
        path = v.fn.tempname() .. '.png'
    end
    if type(path) ~= 'string' or path == '' then
        callback('screenshot: path must be a non-empty string', nil)
        return
    end
    local shot_opts = { format = 'png' }
    local id, err = domains.page.capture_screenshot(ts, shot_opts, function(result, shot_err)
        if shot_err ~= nil then
            callback(shot_err, nil)
            return
        end
        local data = type(result) == 'table' and result.data or nil
        if type(data) ~= 'string' or data == '' then
            callback('screenshot: empty image data', nil)
            return
        end
        if #data > SCREENSHOT_DATA_MAX then
            callback('screenshot: image data exceeds 16 MiB', nil)
            return
        end
        local dok, bytes = pcall(v.base64.decode, data)
        if not dok then
            callback('screenshot: bad base64 data: ' .. tostring(bytes), nil)
            return
        end
        local fh, ferr = io.open(path, 'wb')
        if fh == nil then
            callback('screenshot: cannot write ' .. path .. ': ' .. tostring(ferr), nil)
            return
        end
        fh:write(bytes)
        fh:close()
        notify('Screenshot saved: ' .. path)
        callback(nil, path)
    end)
    if id == nil then
        callback(err, nil)
    end
end

---@param value any
---@return string bounded to STORED_TEXT_MAX chars
local function bound_text(value)
    local text = tostring(value)
    if #text > STORED_TEXT_MAX then
        text = text:sub(1, STORED_TEXT_MAX) .. '...[truncated]'
    end
    return text
end

---@param value any
---@return string|nil nil stays nil, otherwise bounded text
local function bound_text_or_nil(value)
    if value == nil then
        return nil
    end
    return bound_text(value)
end

---Reduce one RemoteObject-ish console arg to a bounded { type, preview }
---pair. The raw object (with its potentially huge description/value) is
---never stored.
---@param arg any
---@return table { type: string, preview: string }
local function normalize_console_arg(arg)
    if type(arg) ~= 'table' then
        return { type = type(arg), preview = bound_text(arg) }
    end
    local raw = arg.value
    if raw == nil then
        raw = arg.description
    end
    if raw == nil then
        raw = arg.type
    end
    return { type = bound_text(arg.type), preview = bound_text(raw) }
end

---Tap console + log events into the ring and emit CdpConsoleMessage.
---Args are normalized to bounded { type, preview } pairs: the raw
---RemoteObjects are never stored, so one huge console.log cannot
---grow the ring's memory without bound.
---@param conn table
---@param ring table from M.new_ring
---@return boolean|nil ok
---@return string|nil err
function M.enable_console_tap(conn, ring)
    local ts, terr = target_session(conn)
    if ts == nil then
        return nil, terr
    end
    domains.runtime.enable(ts)
    domains.log.enable(ts)
    ts:on('Runtime.consoleAPICalled', function(params)
        params = params or {}
        local args = {}
        if type(params.args) == 'table' then
            for i = 1, math.min(#params.args, CONSOLE_ARGS_MAX) do
                args[#args + 1] = normalize_console_arg(params.args[i])
            end
        end
        local entry = {
            kind = 'console',
            type = params.type,
            args = args,
            timestamp = params.timestamp,
        }
        ring:push(entry)
        emit('CdpConsoleMessage', entry)
    end)
    ts:on('Log.entryAdded', function(params)
        params = params or {}
        local raw = params.entry or {}
        local entry = {
            kind = 'log',
            level = raw.level,
            text = bound_text(raw.text),
            url = bound_text_or_nil(raw.url),
        }
        ring:push(entry)
        emit('CdpConsoleMessage', entry)
    end)
    return true
end

---Tap network events into the log. Entries: method, status, url, failed.
---@param conn table
---@param netlog table from M.new_network_log
---@return boolean|nil ok
---@return string|nil err
function M.enable_network_tap(conn, netlog)
    local ts, terr = target_session(conn)
    if ts == nil then
        return nil, terr
    end
    domains.network.enable(ts)
    ts:on('Network.requestWillBeSent', function(params)
        params = params or {}
        local req = params.request or {}
        netlog:push({
            request_id = params.requestId,
            method = req.method,
            url = bound_text_or_nil(req.url),
            mime = params.mimeType,
            failed = false,
        })
    end)
    ts:on('Network.responseReceived', function(params)
        params = params or {}
        local resp = params.response or {}
        netlog:push({
            request_id = params.requestId,
            method = nil,
            url = bound_text_or_nil(resp.url),
            status = resp.status,
            mime = resp.mimeType,
            failed = false,
        })
    end)
    ts:on('Network.loadingFailed', function(params)
        params = params or {}
        netlog:push({
            request_id = params.requestId,
            method = nil,
            url = nil,
            failed = true,
            error_text = bound_text(params.errorText),
        })
    end)
    return true
end

---Debugger awareness only: notify + CdpPaused on pause. No stepping UI;
---diver already has DAP for that.
---@param conn table
---@return boolean|nil ok
---@return string|nil err
function M.enable_debugger_watch(conn)
    local ts, terr = target_session(conn)
    if ts == nil then
        return nil, terr
    end
    domains.debugger.enable(ts)
    ts:on('Debugger.paused', function(params)
        params = params or {}
        notify('CDP paused: ' .. tostring(params.reason))
        emit('CdpPaused', params)
    end)
    ts:on('Debugger.resumed', function()
        notify('CDP resumed')
    end)
    return true
end

---@param entry table
---@return string one bounded line
local function format_console_entry(entry)
    local text = ''
    if entry.kind == 'log' then
        text = '[' .. tostring(entry.level) .. '] ' .. tostring(entry.text)
    else
        text = '[console.' .. tostring(entry.type) .. ']'
        if type(entry.args) == 'table' then
            local parts = {}
            for i = 1, math.min(#entry.args, 4) do
                local arg = entry.args[i]
                local shown = ''
                if type(arg) == 'table' and arg.preview ~= nil then
                    shown = tostring(arg.preview)
                elseif type(arg) == 'table' and arg.value ~= nil then
                    shown = tostring(arg.value)
                elseif type(arg) == 'table' then
                    shown = tostring(arg.type) .. ':' .. tostring(arg.description)
                else
                    shown = tostring(arg)
                end
                parts[#parts + 1] = shown
            end
            text = text .. ' ' .. table.concat(parts, ' ')
        end
    end
    if #text > ENTRY_PREVIEW_MAX then
        text = text:sub(1, ENTRY_PREVIEW_MAX) .. '...'
    end
    return text
end

---@param entry table
---@return string one bounded line
local function format_network_entry(entry)
    if entry.failed then
        return 'FAIL ' .. tostring(entry.error_text) .. ' req=' .. tostring(entry.request_id)
    end
    local parts = {
        tostring(entry.method or '-'),
        tostring(entry.status or '-'),
        tostring(entry.url),
    }
    return table.concat(parts, ' ')
end

---@param title string
---@param lines string[]
local function open_scratch(title, lines)
    local v = rawget(_G, 'vim')
    local buf = v.api.nvim_create_buf(false, true)
    v.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    v.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
    v.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    v.api.nvim_set_option_value('modifiable', false, { buf = buf })
    v.api.nvim_set_option_value('filetype', 'cdp-' .. title:lower():gsub('%s+', '-'), { buf = buf })
    v.cmd('split')
    v.api.nvim_win_set_buf(0, buf)
end

---Show the console ring in a scratch buffer.
---@param ring table from M.new_ring
function M.show_console(ring)
    local lines = {}
    for _, entry in ipairs(ring:entries()) do
        lines[#lines + 1] = format_console_entry(entry)
    end
    if #lines == 0 then
        lines = { '(no console entries yet)' }
    end
    open_scratch('CDP Console', lines)
end

---Show the network log in a scratch buffer.
---@param netlog table from M.new_network_log
function M.show_network(netlog)
    local lines = {}
    for _, entry in ipairs(netlog:entries()) do
        lines[#lines + 1] = format_network_entry(entry)
    end
    if #lines == 0 then
        lines = { '(no network entries yet)' }
    end
    open_scratch('CDP Network', lines)
end

return M
