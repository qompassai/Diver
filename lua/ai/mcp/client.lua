-- /qompassai/Diver/lua/ai/mcp/client.lua
-- Qompass AI MCP stdio JSON-RPC Client (Tiger Style)
---@module 'ai.mcp.client'
-- MCP speaks JSON-RPC 2.0 as newline-delimited messages over the server
-- process's stdio (no Content-Length framing, unlike LSP). This module owns
-- process lifetime, message framing, request/response matching with
-- timeouts, and era negotiation: first contact is the modern
-- `server/discover` probe, and modern sessions stamp every request with
-- `_meta` protocol metadata. A server answering the probe with
-- method-not-found (-32601) is approached through the legacy `initialize`
-- handshake instead; that is the only fallback trigger. One session (one
-- process handle) per server name; teardown is idempotent.
--
-- Opportunistic reuse: if 'ai.rose.mcp' is requireable and exposes
-- new_stdio_client(argv) returning a table with function fields
-- request(method, params, callback), notify(method, params) and stop(),
-- that transport is used; otherwise -- including today, where the module
-- does not exist -- the native implementation below is used. The probe is
-- best-effort and never raises; timeouts and pending-request tracking stay
-- in this module either way.

local registry = require('ai.mcp.registry')
local secrets = require('ai.mcp.secrets')

local M = {}

local CLIENT_NAME = 'diver-mcp'
local CLIENT_VERSION = '0.1.0'
local INITIALIZE_TIMEOUT_MS = 15000
local LEGACY_PROTOCOL_VERSION = '2024-11-05'
local LINE_BYTES_MAX = 8 * 1024 * 1024
local METHOD_NOT_FOUND_CODE = -32601
local MODERN_PROTOCOL_VERSION = '2026-07-28'
local PENDING_REQUESTS_MAX = 64
local REQUEST_TIMEOUT_MS_DEFAULT = 30000
local UNSUPPORTED_VERSION_CODE = -32022

---@class McpPending
---@field callback fun(err: string?, result: table?, raw_error: table?)
---@field timer uv.uv_timer_t?

---@class McpBackend
---@field send fun(payload: table, on_response: (fun(response: table))?)
---@field notify fun(payload: table)
---@field close fun()

---@class McpSession
---@field backend McpBackend?
---@field buffer string
---@field capabilities table?
---@field era string?
---@field generation integer
---@field name string
---@field next_id integer
---@field pending table<integer, McpPending>
---@field protocol_version string?
---@field ready boolean

local sessions = {} ---@type table<string, McpSession>

---@param argv string[]
---@return table? transport with request/notify/stop function fields, or nil
local function probe_rose(argv)
    local ok, rose = pcall(require, 'ai.rose.mcp')
    if not ok or type(rose) ~= 'table' then
        return nil
    end
    if type(rose.new_stdio_client) ~= 'function' then
        return nil
    end
    local sok, transport = pcall(rose.new_stdio_client, argv)
    if not sok or type(transport) ~= 'table' then
        return nil
    end
    if type(transport.request) ~= 'function' then
        return nil
    end
    if type(transport.notify) ~= 'function' then
        return nil
    end
    if type(transport.stop) ~= 'function' then
        return nil
    end
    return transport
end

---@param transport table
---@return McpBackend
local function rose_backend(transport)
    ---@type McpBackend
    return {
        close = function()
            pcall(transport.stop)
        end,
        notify = function(payload)
            transport.notify(payload.method, payload.params or {})
        end,
        send = function(payload, on_response)
            if on_response ~= nil then
                local id = payload.id
                transport.request(payload.method, payload.params or {}, function(err, result)
                    on_response({ id = id, result = result, error = err })
                end)
            else
                transport.notify(payload.method, payload.params or {})
            end
        end,
    }
end

---@param session McpSession
---@param id integer
---@param err string?
---@param result table?
---@param raw_error table?
local function resolve_pending(session, id, err, result, raw_error)
    local pending = session.pending[id]
    if pending == nil then
        return
    end
    session.pending[id] = nil
    if pending.timer ~= nil then
        pcall(pending.timer.stop, pending.timer)
        pcall(pending.timer.close, pending.timer)
        pending.timer = nil
    end
    pending.callback(err, result, raw_error)
end

---Render the protocol versions a peer declares, from either a discover
---result or an UnsupportedProtocolVersionError's data (the two shapes use
---`supportedVersions` and `supported` respectively).
---@param source any
---@return string
local function version_list_text(source)
    if type(source) ~= 'table' then
        return 'unknown'
    end
    local list = source.supportedVersions or source.supported
    if type(list) ~= 'table' then
        return 'unknown'
    end
    local names = {}
    for _, value in ipairs(list) do
        names[#names + 1] = tostring(value)
    end
    if #names == 0 then
        return 'unknown'
    end
    return table.concat(names, ', ')
end

---@param list any
---@param wanted string
---@return boolean
local function version_list_contains(list, wanted)
    if type(list) ~= 'table' then
        return false
    end
    for _, value in ipairs(list) do
        if value == wanted then
            return true
        end
    end
    return false
end

---@param detail any
---@return string
local function error_text(detail)
    if type(detail) == 'string' then
        return detail
    end
    if type(detail) == 'table' and detail.code == UNSUPPORTED_VERSION_CODE then
        local message = type(detail.message) == 'string' and detail.message or 'unsupported protocol version'
        return 'UnsupportedProtocolVersionError: '
            .. message
            .. ' (server supports: '
            .. version_list_text(detail.data)
            .. ')'
    end
    if type(detail) == 'table' and type(detail.message) == 'string' then
        return detail.message
    end
    return 'request failed'
end

---@param session McpSession
---@param line string
local function handle_line(session, line)
    if line == '' or #line > LINE_BYTES_MAX then
        return
    end
    local ok, message = pcall(vim.json.decode, line)
    if not ok or type(message) ~= 'table' then
        return
    end
    if message.id ~= nil and (message.result ~= nil or message.error ~= nil) then
        local err = nil
        local raw_error = nil
        if message.error ~= nil then
            err = error_text(message.error)
            if type(message.error) == 'table' then
                raw_error = message.error
            end
        end
        local result = type(message.result) == 'table' and message.result or nil
        resolve_pending(session, message.id, err, result, raw_error)
        return
    end
    -- Server->client requests are not needed by the manager; answer with
    -- "method not found" so servers never hang waiting for a reply.
    if message.id ~= nil and message.method ~= nil and session.backend ~= nil then
        session.backend.send({
            jsonrpc = '2.0',
            id = message.id,
            error = { code = -32601, message = 'Method not found' },
        })
    end
end

---@param session McpSession
---@param data string
local function feed_stdout(session, data)
    session.buffer = session.buffer .. data
    while true do
        local newline = session.buffer:find('\n', 1, true)
        if not newline then
            break
        end
        local line = session.buffer:sub(1, newline - 1)
        session.buffer = session.buffer:sub(newline + 1)
        handle_line(session, line)
    end
    if #session.buffer > LINE_BYTES_MAX then
        session.buffer = ''
    end
end

---@param _session McpSession kept for signature symmetry with rose_backend
---@param proc_holder { proc: vim.SystemObj? }
---@return McpBackend
local function native_backend(_session, proc_holder)
    local function write_line(payload)
        local proc = proc_holder.proc
        if proc == nil then
            return
        end
        local ok, text = pcall(vim.json.encode, payload)
        if ok then
            pcall(proc.write, proc, text .. '\n')
        end
    end
    ---@type McpBackend
    return {
        close = function()
            local proc = proc_holder.proc
            proc_holder.proc = nil
            if proc ~= nil then
                pcall(proc.kill, proc, 15)
            end
        end,
        notify = function(payload)
            write_line(payload)
        end,
        send = function(payload, _on_response)
            write_line(payload)
        end,
    }
end

---@param session McpSession
---@param payload table
---@param timeout_ms integer
---@param callback fun(err: string?, result: table?, raw_error: table?)
local function send_request(session, payload, timeout_ms, callback)
    assert(session.backend ~= nil, 'session has no backend')
    if vim.tbl_count(session.pending) >= PENDING_REQUESTS_MAX then
        callback('pending request bound exceeded', nil)
        return
    end
    local id = session.next_id
    session.next_id = session.next_id + 1
    payload.id = id
    local timer = vim.uv.new_timer()
    if timer == nil then
        callback('cannot create request timer', nil)
        return
    end
    session.pending[id] = { callback = callback, timer = timer }
    local generation = session.generation
    timer:start(timeout_ms, 0, function()
        vim.schedule(function()
            if session.generation == generation then
                resolve_pending(session, id, 'request timed out after ' .. timeout_ms .. 'ms', nil)
            end
        end)
    end)
    session.backend.send(payload, function(response)
        vim.schedule(function()
            if session.generation ~= generation then
                return
            end
            local err = nil
            local raw_error = nil
            if response.error ~= nil then
                err = error_text(response.error)
                if type(response.error) == 'table' then
                    raw_error = response.error
                end
            end
            resolve_pending(session, id, err, response.result, raw_error)
        end)
    end)
end

---@param session McpSession
---@param reason string
local function teardown(session, reason)
    session.generation = session.generation + 1
    session.ready = false
    local ids = {}
    for id in pairs(session.pending) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        resolve_pending(session, id, reason, nil)
    end
    if session.backend ~= nil then
        session.backend.close()
        session.backend = nil
    end
    sessions[session.name] = nil
end

---The per-request metadata the modern era requires: the protocol version
---in use plus this client's identity and capabilities.
---@param protocol_version string
---@return table
local function request_meta(protocol_version)
    return {
        ['io.modelcontextprotocol/clientCapabilities'] = vim.empty_dict(),
        ['io.modelcontextprotocol/clientInfo'] = { name = CLIENT_NAME, version = CLIENT_VERSION },
        ['io.modelcontextprotocol/protocolVersion'] = protocol_version,
    }
end

---Copy params and stamp `_meta` on the copy when the session negotiated
---the modern era; legacy sessions pass params through untouched so their
---wire shape is byte-identical to before. Callers keep ownership of the
---table they passed.
---@param session McpSession
---@param params table?
---@return table?
local function stamp_meta(session, params)
    if session.era ~= 'modern' then
        return params
    end
    local stamped = {}
    if params ~= nil then
        for key, value in pairs(params) do
            stamped[key] = value
        end
    end
    stamped._meta = request_meta(session.protocol_version or MODERN_PROTOCOL_VERSION)
    return stamped
end

---@param session McpSession
---@param name string
---@param argv string[]
---@param entry McpServerEntry
---@return boolean spawned
---@return string? err
local function spawn_native(session, name, argv, entry)
    local proc_holder = { proc = nil } ---@type { proc: vim.SystemObj? }
    session.backend = native_backend(session, proc_holder)
    -- Merge static env with secrets resolved at spawn time. Resolved values
    -- live only in this table and the child environment; they are never
    -- persisted or logged.
    local merged_env = {} ---@type table<string, string>
    if entry.env ~= nil then
        for key, value in pairs(entry.env) do
            merged_env[key] = value
        end
    end
    if entry.secrets ~= nil then
        local resolved, resolve_err = secrets.resolve(entry)
        if resolved == nil then
            return false, resolve_err
        end
        for key, value in pairs(resolved) do
            merged_env[key] = value
        end
    end
    local env_list = nil ---@type string[]?
    if next(merged_env) ~= nil then
        env_list = {}
        for key, value in pairs(merged_env) do
            env_list[#env_list + 1] = key .. '=' .. value
        end
        table.sort(env_list)
    end
    local spawned, process = pcall(vim.system, argv, {
        cwd = entry.cwd,
        env = env_list,
        stdin = true,
        stdout = function(_err, data)
            if data ~= nil then
                feed_stdout(session, data)
            end
        end,
        stderr = function() end,
    }, function(result)
        vim.schedule(function()
            if sessions[name] == session then
                teardown(session, 'server exited with code ' .. tostring(result.code))
            end
        end)
    end)
    if not spawned then
        return false, 'failed to spawn ' .. entry.command .. ': ' .. tostring(process)
    end
    ---@cast process vim.SystemObj
    proc_holder.proc = process
    return true, nil
end

---@param session McpSession
---@param name string
---@param on_ready fun(err: string?)
local function run_legacy_handshake(session, name, on_ready)
    local params = {
        protocolVersion = LEGACY_PROTOCOL_VERSION,
        -- vim.empty_dict: an empty Lua table encodes as [], which strict
        -- MCP servers reject for the required capabilities object.
        capabilities = vim.empty_dict(),
        clientInfo = { name = CLIENT_NAME, version = CLIENT_VERSION },
    }
    local payload = { jsonrpc = '2.0', method = 'initialize', params = params }
    send_request(session, payload, INITIALIZE_TIMEOUT_MS, function(err, result)
        if sessions[name] ~= session then
            on_ready('session replaced during handshake')
            return
        end
        if err ~= nil then
            teardown(session, 'initialize failed')
            on_ready('initialize failed: ' .. err)
            return
        end
        local backend = session.backend
        assert(backend ~= nil, 'session lost its backend during handshake')
        backend.notify({ jsonrpc = '2.0', method = 'notifications/initialized', params = vim.empty_dict() })
        session.era = 'legacy'
        session.protocol_version = LEGACY_PROTOCOL_VERSION
        if type(result) == 'table' then
            session.capabilities = result.capabilities or {}
            if type(result.protocolVersion) == 'string' then
                session.protocol_version = result.protocolVersion
            end
        end
        session.ready = true
        on_ready(nil)
    end)
end

---Discover-first negotiation: `server/discover` is always the first frame.
---Only a method-not-found answer (-32601) identifies a legacy server and
---triggers the bounded fallback to `initialize`; every other failure —
---including a version rejection — ends the handshake, so a modern server
---in a bad state is never silently re-approached as a legacy one.
---@param session McpSession
---@param name string
---@param on_ready fun(err: string?)
local function run_handshake(session, name, on_ready)
    local payload = {
        jsonrpc = '2.0',
        method = 'server/discover',
        params = { _meta = request_meta(MODERN_PROTOCOL_VERSION) },
    }
    send_request(session, payload, INITIALIZE_TIMEOUT_MS, function(err, result, raw_error)
        if sessions[name] ~= session then
            on_ready('session replaced during handshake')
            return
        end
        if err == nil and type(result) == 'table' then
            if not version_list_contains(result.supportedVersions, MODERN_PROTOCOL_VERSION) then
                local reason = 'no mutually supported modern protocol version (server supports: '
                    .. version_list_text(result)
                    .. ')'
                teardown(session, reason)
                on_ready(reason)
                return
            end
            session.capabilities = result.capabilities or {}
            session.era = 'modern'
            session.protocol_version = MODERN_PROTOCOL_VERSION
            session.ready = true
            on_ready(nil)
            return
        end
        if type(raw_error) == 'table' and raw_error.code == METHOD_NOT_FOUND_CODE then
            run_legacy_handshake(session, name, on_ready)
            return
        end
        teardown(session, 'server/discover failed')
        on_ready('server/discover failed: ' .. (err or 'malformed discover result'))
    end)
end

---@param name string
---@param entry McpServerEntry
---@param on_ready fun(err: string?)
local function spawn(name, entry, on_ready)
    local argv = { entry.command }
    for _, arg in ipairs(entry.args) do
        argv[#argv + 1] = arg
    end

    ---@type McpSession
    local session = {
        backend = nil,
        buffer = '',
        generation = 1,
        name = name,
        next_id = 1,
        pending = {},
        ready = false,
    }
    sessions[name] = session

    local rose_transport = probe_rose(argv)
    if rose_transport ~= nil then
        session.backend = rose_backend(rose_transport)
    else
        local spawned, spawn_err = spawn_native(session, name, argv, entry)
        if not spawned then
            teardown(session, 'spawn failed')
            on_ready(spawn_err)
            return
        end
    end

    run_handshake(session, name, on_ready)
end

---@param name string
---@return boolean
function M.is_ready(name)
    local session = sessions[name]
    return session ~= nil and session.ready
end

---@param name string
---@return boolean
function M.is_running(name)
    return sessions[name] ~= nil
end

---@param name string
---@param method string
---@param params table
function M.notify(name, method, params)
    local session = sessions[name]
    if session == nil or not session.ready or session.backend == nil then
        return
    end
    session.backend.notify({ jsonrpc = '2.0', method = method, params = stamp_meta(session, params) })
end

---@param name string
---@param method string
---@param params table
---@param callback fun(err: string?, result: table?)
---@param timeout_ms? integer
function M.request(name, method, params, callback, timeout_ms)
    assert(type(name) == 'string' and name ~= '', 'name must be a non-empty string')
    assert(type(method) == 'string' and method ~= '', 'method must be a non-empty string')
    assert(type(callback) == 'function', 'callback must be a function')
    local session = sessions[name]
    if session == nil or not session.ready then
        callback('server is not running: ' .. name, nil)
        return
    end
    -- An empty Lua table encodes as []; strict MCP servers require params
    -- to be an object and silently drop the request otherwise.
    if type(params) == 'table' and next(params) == nil then
        params = vim.empty_dict()
    end
    send_request(session, {
        jsonrpc = '2.0',
        method = method,
        params = stamp_meta(session, params),
    }, timeout_ms or REQUEST_TIMEOUT_MS_DEFAULT, callback)
end

---@param name string
---@param on_ready fun(err: string?)
function M.start(name, on_ready)
    assert(type(name) == 'string' and name ~= '', 'name must be a non-empty string')
    assert(type(on_ready) == 'function', 'on_ready must be a function')
    local existing = sessions[name]
    if existing ~= nil then
        if existing.ready then
            on_ready(nil)
        else
            on_ready('server is still starting: ' .. name)
        end
        return
    end
    local entry = registry.get(name)
    if entry == nil then
        on_ready('unknown server: ' .. name)
        return
    end
    if not entry.enabled then
        on_ready('server is disabled: ' .. name)
        return
    end
    local valid, validation_err = registry.validate(entry)
    if not valid then
        on_ready('invalid server config: ' .. tostring(validation_err))
        return
    end
    assert(validation_err == nil, 'validate returned false with no error')
    spawn(name, entry, on_ready)
end

---@param name string
function M.stop(name)
    local session = sessions[name]
    if session == nil then
        return
    end
    teardown(session, 'stopped')
end

function M.stop_all()
    local names = {}
    for name in pairs(sessions) do
        names[#names + 1] = name
    end
    for _, name in ipairs(names) do
        M.stop(name)
    end
end

return M
