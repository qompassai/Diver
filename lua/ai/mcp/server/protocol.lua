-- /qompassai/Diver/lua/ai/mcp/server/protocol.lua
-- Qompass AI MCP Server Protocol Engine (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Transport-agnostic JSON-RPC 2.0 engine for the MCP server side.
--
-- Plain words: this is the referee for the conversation. It reads one
-- newline-delimited JSON message at a time, checks its shape, runs the
-- `initialize` version handshake, answers `ping`, and dispatches
-- `tools/list` / `tools/call` to the tool registry the caller supplies.
-- It knows nothing about stdio: the caller injects `write` (one encoded
-- line, no trailing newline) and a JSON codec, which keeps this module
-- runnable under plain Lua for tests.
--
-- Error policy: -32700 parse error (malformed line, null id), -32600
-- invalid request, -32601 unknown method, -32602 bad params, -32603
-- handler crash. Tool *execution* failures are successful responses with
-- `isError = true`; only unknown tools, bad shapes, and crashes become
-- protocol errors.

local M = {}

local SERVER_NAME = 'diver-mcp-server'
local SERVER_VERSION = '0.1.0'
local PROTOCOL_VERSION_DEFAULT = '2025-11-25'
local SUPPORTED_VERSIONS = { ['2025-11-25'] = true, ['2024-11-05'] = true }
-- Mirrors ai.mcp.client's framing bound so both sides agree on line size.
local LINE_BYTES_MAX = 8 * 1024 * 1024

local ERR_INVALID_REQUEST = -32600
local ERR_METHOD_NOT_FOUND = -32601
local ERR_INVALID_PARAMS = -32602
local ERR_INTERNAL = -32603
local ERR_PARSE = -32700

---@class McpJsonCodec
---@field encode fun(value: any): string
---@field decode fun(text: string): any

---@class McpServerError
---@field code integer JSON-RPC error code.
---@field message string Human-readable reason.

---@class McpToolsProvider
---@field list fun(): table[] Tool descriptors, no handlers.
---@field call fun(name: string, args: table, meta: table?): table?, McpServerError?

---@class McpServerOpts
---@field json McpJsonCodec? Defaults to vim.json when available.
---@field write fun(line: string) Transport write; exactly one line.
---@field tools McpToolsProvider? Registers tools/list and tools/call.
---@field on_log fun(level: string, message: string)? Defaults to no-op.

---@return McpJsonCodec?
local function default_json()
    if vim ~= nil and vim.json ~= nil and vim.json.encode ~= nil and vim.json.decode ~= nil then
        return vim.json
    end
    return nil
end

---@param server table
---@param id string|number|nil
---@param payload table
local function send(server, id, payload)
    payload.jsonrpc = '2.0'
    payload.id = id
    local ok, line = pcall(server.json.encode, payload)
    if not ok or type(line) ~= 'string' then
        server.on_log('error', 'failed to encode response')
        return
    end
    local wrote, write_err = pcall(server.write, line)
    if not wrote then
        server.on_log('error', 'transport write failed: ' .. tostring(write_err))
    end
end

---@param server table
---@param id string|number|nil
---@param code integer
---@param message string
local function send_error(server, id, code, message)
    send(server, id, { error = { code = code, message = message } })
end

---@param server table
---@param id string|number
---@param result table
local function send_result(server, id, result)
    send(server, id, { result = result })
end

-- JSON-RPC 2.0 section 5.1: a line that is not JSON at all gets a Parse
-- error whose id MUST be null (the request id could not be recovered).
-- The payload is a fixed string on purpose: the codec just failed on this
-- input, so the error path does not depend on the codec to format itself.
local PARSE_ERROR_LINE =
    '{"jsonrpc":"2.0","id":null,"error":{"code":-32700,"message":"Parse error"}}'

---@param server table
local function send_parse_error(server)
    local wrote, write_err = pcall(server.write, PARSE_ERROR_LINE)
    if not wrote then
        server.on_log('error', 'transport write failed: ' .. tostring(write_err))
    end
end

-- Version handshake. Accepts 2025-11-25 and 2024-11-05; anything else
-- (including a missing version, which is rejected) falls back to the
-- server default rather than failing the handshake.
---@param params table
---@return table? result
---@return McpServerError? err
local function handle_initialize(params)
    local version = params.protocolVersion
    if type(version) ~= 'string' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'protocolVersion must be a string' }
    end
    local capabilities = params.capabilities
    if capabilities == nil then
        capabilities = {}
    end
    if type(capabilities) ~= 'table' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'capabilities must be an object' }
    end
    local negotiated = PROTOCOL_VERSION_DEFAULT
    if SUPPORTED_VERSIONS[version] then
        negotiated = version
    end
    return {
        protocolVersion = negotiated,
        capabilities = { tools = { listChanged = false } },
        serverInfo = { name = SERVER_NAME, version = SERVER_VERSION },
        instructions = 'Diver MCP server. Reads are auto-approved; writes need a confirmation '
            .. 'grant; run_command uses a bare-name allowlist (default deny) and never a shell.',
    }
end

---@param server table
---@param params table
local function handle_tools_list(server, params)
    local cursor = params.cursor
    if cursor ~= nil and type(cursor) ~= 'string' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'cursor must be a string' }
    end
    return { tools = server.tools.list() }
end

-- Note: params._meta carries the optional confirmation grant token.
---@param server table
---@param params table
local function handle_tools_call(server, params)
    local name = params.name
    if type(name) ~= 'string' or name == '' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'name must be a non-empty string' }
    end
    local args = params.arguments
    if args == nil then
        args = {}
    end
    if type(args) ~= 'table' then
        return nil, { code = ERR_INVALID_PARAMS, message = 'arguments must be an object' }
    end
    local meta = params._meta
    if meta ~= nil and type(meta) ~= 'table' then
        return nil, { code = ERR_INVALID_PARAMS, message = '_meta must be an object' }
    end
    return server.tools.call(name, args, meta)
end

---@param server table
---@param msg table decoded JSON-RPC message
local function dispatch_notification(server, msg)
    local handler = server.notif_handlers[msg.method]
    if handler == nil then
        return
    end
    local params = msg.params
    if params == nil then
        params = {}
    end
    if type(params) ~= 'table' then
        return
    end
    local ok, err = pcall(handler, params)
    if not ok then
        server.on_log('error', 'notification handler crashed: ' .. tostring(err))
    end
end

---@param server table
---@param msg table decoded JSON-RPC message
local function dispatch_request(server, msg)
    local id = msg.id
    if id ~= nil and type(id) ~= 'string' and type(id) ~= 'number' then
        send_error(server, nil, ERR_INVALID_REQUEST, 'request id must be a string or number')
        return
    end
    if id == nil then
        dispatch_notification(server, msg)
        return
    end
    -- Gate: only initialize and ping are answered before the client sends
    -- notifications/initialized.
    if not server.initialized and msg.method ~= 'initialize' and msg.method ~= 'ping' then
        send_error(server, id, ERR_INVALID_REQUEST, 'server not initialized')
        return
    end
    local handler = server.handlers[msg.method]
    if handler == nil then
        send_error(server, id, ERR_METHOD_NOT_FOUND, 'method not found: ' .. msg.method)
        return
    end
    local params = msg.params
    if params == nil then
        params = {}
    end
    if type(params) ~= 'table' then
        send_error(server, id, ERR_INVALID_PARAMS, 'params must be an object')
        return
    end
    local ok, result, herr = pcall(handler, params)
    if not ok then
        server.on_log('error', 'handler crashed: ' .. tostring(result))
        send_error(server, id, ERR_INTERNAL, 'internal error')
        return
    end
    if result == nil then
        local code = ERR_INTERNAL
        local message = 'internal error'
        if type(herr) == 'table' then
            if type(herr.code) == 'number' then
                code = herr.code
            end
            if type(herr.message) == 'string' then
                message = herr.message
            end
        elseif type(herr) == 'string' then
            message = herr
        end
        send_error(server, id, code, message)
        return
    end
    send_result(server, id, result)
end

---@param server table
---@param msg table decoded JSON-RPC message
local function dispatch(server, msg)
    if msg[1] ~= nil then
        send_error(server, msg.id, ERR_INVALID_REQUEST, 'batch requests are not supported')
        return
    end
    if msg.jsonrpc ~= '2.0' or type(msg.method) ~= 'string' then
        if msg.id ~= nil then
            send_error(server, msg.id, ERR_INVALID_REQUEST, 'invalid request')
        end
        return
    end
    dispatch_request(server, msg)
end

-- Wire the built-in JSON-RPC surface: initialize, ping, and the optional
-- tool handlers when a tool provider is supplied.
---@param server table
---@param opts table
local function register_builtins(server, opts)
    server:register('initialize', handle_initialize)
    server:register('ping', function()
        return {}
    end)
    if opts.tools ~= nil then
        assert(type(opts.tools.list) == 'function', 'opts.tools.list is required')
        assert(type(opts.tools.call) == 'function', 'opts.tools.call is required')
        server:register('tools/list', function(params)
            return handle_tools_list(server, params)
        end)
        server:register('tools/call', function(params)
            return handle_tools_call(server, params)
        end)
    end
    server:on_notification('notifications/initialized', function()
        server.initialized = true
    end)
    server:on_notification('notifications/cancelled', function() end)
end

-- Create a server. `opts.write` and a JSON codec are required; everything
-- else has a default. Registering is done via the returned server's
-- `register` / `on_notification` methods.
---@param opts McpServerOpts
---@return table server
function M.new(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.write) == 'function', 'opts.write is required')
    local json = opts.json or default_json()
    assert(json ~= nil, 'a JSON codec is required (opts.json or vim.json)')
    local on_log = opts.on_log
    if on_log == nil then
        on_log = function() end
    end
    assert(type(on_log) == 'function', 'opts.on_log must be a function')

    local server = {
        json = json,
        write = opts.write,
        on_log = on_log,
        tools = opts.tools,
        handlers = {},
        notif_handlers = {},
        initialized = false,
    }

    ---@param method string
    ---@param fn fun(params: table): table?, McpServerError?
    function server:register(method, fn)
        assert(type(method) == 'string' and method ~= '', 'method must be a non-empty string')
        assert(type(fn) == 'function', 'handler must be a function')
        server.handlers[method] = fn
    end

    ---@param method string
    ---@param fn fun(params: table)
    function server:on_notification(method, fn)
        assert(type(method) == 'string' and method ~= '', 'method must be a non-empty string')
        assert(type(fn) == 'function', 'handler must be a function')
        server.notif_handlers[method] = fn
    end

    ---@return boolean
    function server:is_initialized()
        return server.initialized
    end

    -- Feed one newline-stripped line from the transport. Never raises.
    -- Blank lines are transport noise and ignored. Unparsable input gets
    -- a -32700 Parse error (null id); oversized lines are still dropped
    -- unparsed (transport bound, never decoded).
    ---@param line string
    function server:handle_line(line)
        if type(line) ~= 'string' or line:match('^%s*$') then
            return
        end
        if #line > LINE_BYTES_MAX then
            server.on_log('warn', 'dropped oversized line of ' .. #line .. ' bytes')
            return
        end
        local ok, msg = pcall(server.json.decode, line)
        if not ok then
            server.on_log('warn', 'unparsable line, sent -32700')
            send_parse_error(server)
            return
        end
        if type(msg) ~= 'table' then
            server.on_log('warn', 'dropped non-object line')
            return
        end
        dispatch(server, msg)
    end

    register_builtins(server, opts)

    return server
end

return M
