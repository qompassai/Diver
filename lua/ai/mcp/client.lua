-- /qompassai/Diver/lua/ai/mcp/client.lua
-- Qompass AI MCP stdio JSON-RPC Client (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- MCP speaks JSON-RPC 2.0 as newline-delimited messages over the server
-- process's stdio (no Content-Length framing, unlike LSP). This module owns
-- process lifetime, message framing, request/response matching with
-- timeouts, and the initialize handshake. One session (one process handle)
-- per server name; teardown is idempotent.
--
-- Opportunistic reuse: if 'ai.rose.mcp' is requireable and exposes
-- new_stdio_client(argv) returning a table with function fields
-- request(method, params, callback), notify(method, params) and stop(),
-- that transport is used; otherwise -- including today, where the module
-- does not exist -- the native implementation below is used. The probe is
-- best-effort and never raises; timeouts and pending-request tracking stay
-- in this module either way.

local registry = require('ai.mcp.registry')

local M = {}

local MCP_PROTOCOL_VERSION = '2024-11-05'
local LINE_BYTES_MAX = 8 * 1024 * 1024
local PENDING_REQUESTS_MAX = 64
local REQUEST_TIMEOUT_MS_DEFAULT = 30000
local INITIALIZE_TIMEOUT_MS = 15000

---@class McpPending
---@field callback fun(err: string?, result: table?)
---@field timer userdata?

---@class McpBackend
---@field send fun(payload: table, on_response: (fun(response: table))?)
---@field notify fun(payload: table)
---@field close fun()

---@class McpSession
---@field name string
---@field backend McpBackend?
---@field buffer string
---@field next_id integer
---@field pending table<integer, McpPending>
---@field ready boolean
---@field generation integer

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
        notify = function(payload)
            transport.notify(payload.method, payload.params or {})
        end,
        close = function()
            pcall(transport.stop)
        end,
    }
end

---@param session McpSession
---@param id integer
---@param err string?
---@param result table?
local function resolve_pending(session, id, err, result)
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
    pending.callback(err, result)
end

---@param detail any
---@return string
local function error_text(detail)
    if type(detail) == 'string' then
        return detail
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
        if message.error ~= nil then
            err = error_text(message.error)
        end
        local result = type(message.result) == 'table' and message.result or nil
        resolve_pending(session, message.id, err, result)
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
        send = function(payload, _on_response)
            write_line(payload)
        end,
        notify = function(payload)
            write_line(payload)
        end,
        close = function()
            local proc = proc_holder.proc
            proc_holder.proc = nil
            if proc ~= nil then
                pcall(proc.kill, proc, 15)
            end
        end,
    }
end

---@param session McpSession
---@param payload table
---@param timeout_ms integer
---@param callback fun(err: string?, result: table?)
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
            if response.error ~= nil then
                err = error_text(response.error)
            end
            resolve_pending(session, id, err, response.result)
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

---@param session McpSession
---@param name string
---@param argv string[]
---@param entry McpServerEntry
---@return boolean spawned
---@return string? err
local function spawn_native(session, name, argv, entry)
    local proc_holder = { proc = nil } ---@type { proc: vim.SystemObj? }
    session.backend = native_backend(session, proc_holder)
    local env_list = nil ---@type string[]?
    if entry.env ~= nil then
        env_list = {}
        for key, value in pairs(entry.env) do
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
    proc_holder.proc = process
    return true, nil
end

---@param session McpSession
---@param name string
---@param on_ready fun(err: string?)
local function run_handshake(session, name, on_ready)
    local params = {
        protocolVersion = MCP_PROTOCOL_VERSION,
        capabilities = {},
        clientInfo = { name = 'diver-mcp', version = '0.1.0' },
    }
    local payload = { jsonrpc = '2.0', method = 'initialize', params = params }
    send_request(session, payload, INITIALIZE_TIMEOUT_MS, function(err, _result)
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
        backend.notify({ jsonrpc = '2.0', method = 'notifications/initialized', params = {} })
        session.ready = true
        on_ready(nil)
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
        name = name,
        backend = nil,
        buffer = '',
        next_id = 1,
        pending = {},
        ready = false,
        generation = 1,
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
    send_request(session, {
        jsonrpc = '2.0',
        method = method,
        params = params,
    }, timeout_ms or REQUEST_TIMEOUT_MS_DEFAULT, callback)
end

---@param name string
---@param method string
---@param params table
function M.notify(name, method, params)
    local session = sessions[name]
    if session == nil or not session.ready or session.backend == nil then
        return
    end
    session.backend.notify({ jsonrpc = '2.0', method = method, params = params })
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

---@param name string
---@return boolean
function M.is_running(name)
    return sessions[name] ~= nil
end

---@param name string
---@return boolean
function M.is_ready(name)
    local session = sessions[name]
    return session ~= nil and session.ready
end

return M
