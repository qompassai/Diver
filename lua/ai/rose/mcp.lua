-- /qompassai/Diver/lua/ai/rose/mcp.lua
-- MCP stdio client: one JSON-RPC 2.0 object per line (Tiger Style)
---@module 'ai.rose.mcp'
-- Spawns MCP servers over stdio with argv only: no shell, no LSP framing,
-- no plugins. Server-to-client requests are refused except ping. Era
-- negotiation is discover-first: `server/discover` opens the session and
-- modern sessions stamp every request with `_meta` protocol metadata;
-- only a method-not-found (-32601) answer falls back to the legacy
-- `initialize` handshake for that server.

local M = { clients = {} }
local Client = {}
Client.__index = Client
local versions = {
    ['2026-07-28'] = true,
    ['2025-11-25'] = true,
    ['2025-06-18'] = true,
    ['2025-03-26'] = true,
    ['2024-11-05'] = true,
}
local CLIENT_INFO = { name = 'diver', version = '0.2.0' }
local METHOD_NOT_FOUND_CODE = -32601
local MODERN_PROTOCOL_VERSION = '2026-07-28'
local UNSUPPORTED_VERSION_CODE = -32022

---@param callback function?
---@param err string?
---@param result any
---@param raw_error table?
local function defer(callback, err, result, raw_error)
    if callback then
        vim.schedule(function()
            callback(err, result, raw_error)
        end)
    end
end

---@param timer uv.uv_timer_t?
local function stop_timer(timer)
    if timer and not timer:is_closing() then
        timer:stop()
        timer:close()
    end
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

---Format a JSON-RPC error for a request callback. A version rejection
---(-32022) keeps its spec name and the server's supported list, so
---callers can recognize the typed failure instead of a generic string.
---@param err any
---@return string
local function format_error(err)
    if type(err) == 'table' and err.code == UNSUPPORTED_VERSION_CODE then
        return 'UnsupportedProtocolVersionError: '
            .. tostring(err.message or 'unsupported protocol version')
            .. ' (server supports: '
            .. version_list_text(err.data)
            .. ')'
    end
    local text = type(err) == 'table' and err.message or err
    return 'MCP: ' .. tostring(text)
end

---The per-request metadata the modern era requires: the protocol version
---in use plus this client's identity and capabilities.
---@param protocol_version string
---@return table
local function request_meta(protocol_version)
    return {
        ['io.modelcontextprotocol/clientCapabilities'] = vim.empty_dict(),
        ['io.modelcontextprotocol/clientInfo'] = CLIENT_INFO,
        ['io.modelcontextprotocol/protocolVersion'] = protocol_version,
    }
end

---Copy params and stamp `_meta` on the copy when the client negotiated
---the modern era and the caller did not stamp its own; legacy sessions
---pass params through untouched so their wire shape is unchanged.
---@param client table
---@param params table?
---@return table?
local function with_meta(client, params)
    if client.era ~= 'modern' then
        return params
    end
    if params ~= nil and params._meta ~= nil then
        return params
    end
    local stamped = {}
    if params ~= nil then
        for key, value in pairs(params) do
            stamped[key] = value
        end
    end
    stamped._meta = request_meta(client.protocol_version or MODERN_PROTOCOL_VERSION)
    return stamped
end

---@param message table
---@return boolean? sent
---@return string? err
function Client:_send(message)
    if self.closed or not self.process then
        return nil, 'MCP client is closed'
    end
    local ok, encoded = pcall(vim.json.encode, message)
    if not ok then
        return nil, 'MCP encoding failed: ' .. tostring(encoded)
    end
    if #encoded > self.max_message then
        return nil, 'MCP request exceeds size limit'
    end
    local written, err = pcall(self.process.write, self.process, encoded .. '\n')
    if not written then
        return nil, 'MCP write failed: ' .. tostring(err)
    end
    return true
end

---@param id integer|string
---@param err string?
---@param result any
---@param raw_error table?
function Client:_complete(id, err, result, raw_error)
    local pending = self.pending[id]
    if not pending then
        return
    end
    self.pending[id] = nil
    stop_timer(pending.timer)
    defer(pending.callback, err, result, raw_error)
end

---@param method string
---@param params table?
---@return boolean? sent
---@return string? err
function Client:notify(method, params)
    params = with_meta(self, params) or vim.empty_dict()
    return self:_send({ jsonrpc = '2.0', method = method, params = params })
end

---@param method string
---@param params table?
---@param callback fun(err: string?, result: any, raw_error: table?)
---@param timeout integer?
---@return table token
function Client:request(method, params, callback, timeout)
    local token = { cancel = function() end }
    if self.closed then
        defer(callback, 'MCP client is closed')
        return token
    end
    self.sequence = self.sequence + 1
    local id = self.sequence
    local uv = vim.uv or vim.uv
    local timer = uv.new_timer()
    if not timer then
        defer(callback, 'could not create MCP request timer')
        return token
    end
    self.pending[id] = { callback = callback, timer = timer }
    function token.cancel()
        if not self.pending[id] then
            return
        end
        self:notify('notifications/cancelled', { requestId = id, reason = 'client cancelled' })
        self:_complete(id, 'cancelled')
    end
    timer:start(
        timeout or self.timeout,
        0,
        vim.schedule_wrap(function()
            if not self.pending[id] then
                return
            end
            self:notify('notifications/cancelled', { requestId = id, reason = 'request timeout' })
            self:_complete(id, 'MCP timeout: ' .. method)
        end)
    )
    params = with_meta(self, params) or vim.empty_dict()
    local ok, err = self:_send({
        jsonrpc = '2.0',
        id = id,
        method = method,
        params = params,
    })
    if not ok then
        self:_complete(id, err)
    end
    return token
end

---@param message table decoded JSON-RPC object
function Client:_message(message)
    if type(message) ~= 'table' or message.jsonrpc ~= '2.0' then
        self:close('MCP protocol error: expected JSON-RPC 2.0 object')
        return
    end
    if message.method then
        if message.id ~= nil and message.id ~= vim.NIL then
            -- Never execute server-requested sampling, elicitation, roots or arbitrary
            -- editor commands. ping is the only supported server -> client request.
            local response = { jsonrpc = '2.0', id = message.id }
            if message.method == 'ping' then
                response.result = vim.empty_dict()
            else
                response.error = {
                    code = -32601,
                    message = 'Unsupported server request: ' .. tostring(message.method),
                }
            end
            self:_send(response)
        elseif message.method == 'notifications/cancelled' and type(message.params) == 'table' then
            self:_complete(message.params.requestId, 'MCP server cancelled request')
        end
        return
    end
    if type(message.id) ~= 'number' and type(message.id) ~= 'string' then
        self:close('MCP protocol error: response has no valid id')
        return
    end
    if message.error then
        local raw_error = type(message.error) == 'table' and message.error or nil
        self:_complete(message.id, format_error(message.error), nil, raw_error)
    elseif message.result ~= nil then
        self:_complete(message.id, nil, message.result)
    else
        self:_complete(message.id, 'MCP protocol error: missing result/error')
    end
end

---@param err string?
---@param chunk string?
function Client:_stdout(err, chunk)
    if self.closed then
        return
    end
    if err then
        self:close('MCP stdout error: ' .. tostring(err))
        return
    end
    if not chunk then
        return
    end
    self.buffer = self.buffer .. chunk
    if #self.buffer > self.max_message then
        self:close('MCP message exceeds size limit')
        return
    end
    while not self.closed do
        local newline = self.buffer:find('\n', 1, true)
        if not newline then
            break
        end
        local line = self.buffer:sub(1, newline - 1):gsub('\r$', '')
        self.buffer = self.buffer:sub(newline + 1)
        if line ~= '' then
            local ok, message = pcall(vim.json.decode, line)
            if not ok then
                self:close('MCP protocol error: non-JSON stdout')
                return
            end
            self:_message(message)
        end
    end
end

---@param callback fun(err: string?, result: table?)
---@return table token
function Client:list_tools(callback)
    return self:request('tools/list', vim.empty_dict(), function(err, result)
        if not err and (type(result) ~= 'table' or type(result.tools) ~= 'table') then
            err = 'MCP tools/list missing tools array'
        end
        callback(err, result)
    end)
end

---@param name string
---@param args table?
---@param callback fun(err: string?, result: table?)
---@param timeout integer?
---@return table token
function Client:call_tool(name, args, callback, timeout)
    if type(args) == 'table' and next(args) == nil then
        args = vim.empty_dict()
    end
    return self:request('tools/call', { name = name, arguments = args or vim.empty_dict() }, callback, timeout)
end

---@param reason string?
function Client:close(reason)
    if self.closed then
        return
    end
    self.closed = true
    M.clients[self] = nil
    local ids = {}
    for id in pairs(self.pending) do
        ids[#ids + 1] = id
    end
    for _, id in ipairs(ids) do
        self:_complete(id, reason or 'MCP client closed')
    end
    if self.process and not self.exited then
        -- MCP defines EOF/process termination, not an invented "shutdown" method.
        pcall(self.process.write, self.process, nil)
        pcall(self.process.kill, self.process, 15)
        local uv = vim.uv or vim.uv
        self.kill_timer = uv.new_timer()
        if not self.kill_timer then
            pcall(self.process.kill, self.process, 9)
            return
        end
        self.kill_timer:start(500, 0, function()
            if not self.exited then
                pcall(self.process.kill, self.process, 9)
            end
            stop_timer(self.kill_timer)
            self.kill_timer = nil
        end)
    end
end

local MCP_INITIALIZE_TIMEOUT_MS_DEFAULT = 10000
local MCP_MESSAGE_BYTES_MAX_DEFAULT = 8 * 1024 * 1024
local MCP_PROTOCOL_VERSION = '2025-11-25'
local MCP_STDERR_BYTES_MAX = 8192
local MCP_TIMEOUT_MS_DEFAULT = 30000

-- Operating error for a malformed argv, or nil when it can be spawned.
---@param cmd any
---@return string? invalid
local function argv_error(cmd)
    if type(cmd) ~= 'table' or #cmd == 0 then
        return 'MCP cmd must be an explicit argv array'
    end
    for _, arg in ipairs(cmd) do
        if type(arg) ~= 'string' or arg:find('\0', 1, true) then
            return 'MCP argv must contain strings without NUL'
        end
    end
    return nil
end

-- Handshake completion: validate the server's version, then announce readiness.
local function on_initialized(self, callback, err, result)
    if err then
        self:close(err)
        callback(err)
        return
    end
    if type(result) ~= 'table' or not versions[result.protocolVersion] then
        self:close('unsupported MCP protocol version')
        callback('unsupported MCP protocol version')
        return
    end
    self.protocol_version, self.capabilities = result.protocolVersion, result.capabilities or {}
    self.era = 'legacy'
    local sent, send_err = self:notify('notifications/initialized')
    if not sent then
        self:close(send_err)
        callback(send_err)
        return
    end
    self.ready = true
    callback(nil, self)
end

---@class AiRoseMcpStartOptions
---@field cmd string[] server argv
---@field cwd string?
---@field env table<string, string>?
---@field timeout integer?
---@field initialize_timeout integer?
---@field max_message integer?

---@param opts AiRoseMcpStartOptions
---@param callback fun(err: string?, client: table?)
---@return table client
function M.start(opts, callback)
    assert(type(opts) == 'table', 'MCP start requires an options table')
    assert(type(callback) == 'function', 'MCP start requires callback(err, client)')
    local self = setmetatable({
        pending = {},
        sequence = 0,
        buffer = '',
        stderr = '',
        timeout = opts.timeout or MCP_TIMEOUT_MS_DEFAULT,
        max_message = opts.max_message or MCP_MESSAGE_BYTES_MAX_DEFAULT,
    }, Client)
    local function fail(err)
        self:close(err)
        defer(callback, err)
        return self
    end
    if type(vim.system) ~= 'function' then
        return fail('MCP requires vim.system (Neovim 0.10+)')
    end
    local invalid = argv_error(opts.cmd)
    if invalid then
        return fail(invalid)
    end
    local ok, process = pcall(vim.system, opts.cmd, {
        cwd = opts.cwd,
        env = opts.env,
        stdin = true,
        stdout = function(err, data)
            vim.schedule(function()
                self:_stdout(err, data)
            end)
        end,
        stderr = function(_, data)
            if data then
                self.stderr = (self.stderr .. data):sub(-MCP_STDERR_BYTES_MAX)
            end
        end,
    }, function(result)
        vim.schedule(function()
            self.exited = true
            stop_timer(self.kill_timer)
            self.kill_timer = nil
            self:close('MCP process exited (' .. result.code .. '): ' .. self.stderr)
            if self.on_exit then
                self.on_exit()
                self.on_exit = nil
            end
        end)
    end)
    if not ok then
        return fail('MCP spawn failed: ' .. tostring(process))
    end
    self.process = process
    M.clients[self] = true
    local negotiate_timeout = opts.initialize_timeout or MCP_INITIALIZE_TIMEOUT_MS_DEFAULT
    -- Legacy path, entered only from the discover fallback below.
    local function begin_legacy()
        self:request('initialize', {
            protocolVersion = MCP_PROTOCOL_VERSION,
            capabilities = vim.empty_dict(),
            clientInfo = CLIENT_INFO,
        }, function(err, result)
            on_initialized(self, callback, err, result)
        end, negotiate_timeout)
    end
    -- Discover-first: `server/discover` is always the first frame. Only a
    -- method-not-found answer (-32601) identifies a legacy server and
    -- triggers the bounded fallback; every other failure ends the start,
    -- so a modern server in a bad state is never re-approached as legacy.
    self:request('server/discover', { _meta = request_meta(MODERN_PROTOCOL_VERSION) }, function(err, result, raw_error)
        if err then
            if type(raw_error) == 'table' and raw_error.code == METHOD_NOT_FOUND_CODE then
                begin_legacy()
                return
            end
            self:close(err)
            callback(err)
            return
        end
        if type(result) ~= 'table' or not version_list_contains(result.supportedVersions, MODERN_PROTOCOL_VERSION) then
            local reason = 'no mutually supported modern protocol version (server supports: '
                .. version_list_text(result)
                .. ')'
            self:close(reason)
            callback(reason)
            return
        end
        self.capabilities = result.capabilities or {}
        self.era = 'modern'
        self.protocol_version = MODERN_PROTOCOL_VERSION
        self.ready = true
        callback(nil, self)
    end, negotiate_timeout)
    return self
end

-- Close every live MCP client.
--- Close every managed MCP client.
function M.stop()
    local clients = {}
    for client in pairs(M.clients) do
        clients[#clients + 1] = client
    end
    for _, client in ipairs(clients) do
        client:close()
    end
end

return M
