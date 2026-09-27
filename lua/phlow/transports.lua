-- /qompassai/Diver/lua/phlow/transports.lua
-- Pluggable Phlow transports: unix socket, TCP, TLS (stub), WebSocket.
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: these are the different roads a message can travel to
-- reach Phlow. Every road looks the same to the client: connect to get
-- a handle, send bytes, get bytes back, close when done. TLS is a stub
-- on purpose: vim.uv cannot do TLS, and inventing crypto would be a
-- security bug, so asking for TLS fails loudly instead of silently
-- falling back to plaintext.
---@module 'phlow.transports'

local M = {}

---Bound for one transport connect attempt.
---@type integer milliseconds
M.CONNECT_TIMEOUT_MS = 2000

---@class PhlowTransportOpts
---@field path? string unix socket path
---@field host? string tcp/tls host
---@field port? integer tcp/tls port
---@field url? string websocket url (ws:// only; wss:// needs TLS)

---@class PhlowTransportHandle
---@field send fun(self: PhlowTransportHandle, data: string): boolean?, string?
---@field on_data fun(self: PhlowTransportHandle, fn: fun(chunk: string))
---@field close fun(self: PhlowTransportHandle)

---Run an async uv connect to completion, bounded by CONNECT_TIMEOUT_MS.
---@param start fun(done: fun(err: string?)) begins the connect; calls done once
---@return boolean ok
---@return string? err
local function await_connect(start)
    local finished = false
    local connect_err = nil
    start(function(err)
        finished = true
        connect_err = err
    end)
    local done = vim.wait(M.CONNECT_TIMEOUT_MS, function()
        return finished
    end, 50)
    if done ~= true then
        return false, 'connect timed out after ' .. M.CONNECT_TIMEOUT_MS .. 'ms'
    end
    if connect_err ~= nil then
        return false, connect_err
    end
    return true, nil
end

---Wrap a connected uv stream (pipe or tcp) in the common handle shape.
---@param stream userdata uv stream with read_start/write/close
---@return PhlowTransportHandle
local function wrap_stream(stream)
    ---@type PhlowTransportHandle
    local handle = { _closed = false, _on_data = nil }
    function handle:send(data)
        assert(type(data) == 'string', 'data must be a string')
        if self._closed then
            return nil, 'transport is closed'
        end
        local ok, err = pcall(stream.write, stream, data)
        if not ok then
            return nil, 'write failed: ' .. tostring(err)
        end
        return true, nil
    end
    function handle:on_data(fn)
        assert(type(fn) == 'function', 'fn must be a function')
        self._on_data = fn
    end
    function handle:close()
        if self._closed then
            return
        end
        self._closed = true
        self._on_data = nil
        pcall(stream.close, stream)
    end
    stream:read_start(function(read_err, chunk)
        local fn = handle._on_data
        if handle._closed or fn == nil then
            return
        end
        if read_err ~= nil or chunk == nil then
            return -- EOF or read error: requests fail on their own timeout
        end
        fn(chunk)
    end)
    return handle
end

---Unix socket transport (priority 1). Needs opts.path.
M.unix = {}
---@param opts PhlowTransportOpts
---@return PhlowTransportHandle? handle
---@return string? err
function M.unix.connect(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    if vim.uv == nil then
        return nil, 'vim.uv is unavailable'
    end
    local path = opts.path
    if type(path) ~= 'string' or path == '' then
        return nil, 'unix transport needs opts.path'
    end
    local pipe = vim.uv.new_pipe(false)
    if pipe == nil then
        return nil, 'could not create pipe handle'
    end
    local ok, err = await_connect(function(done)
        pipe:connect(path, function(connect_err)
            done(connect_err)
        end)
    end)
    if not ok then
        pcall(pipe.close, pipe)
        return nil, 'unix socket ' .. path .. ': ' .. tostring(err)
    end
    return wrap_stream(pipe), nil
end

---TCP transport (priority 2). Needs opts.host and opts.port.
M.tcp = {}
---@param opts PhlowTransportOpts
---@return PhlowTransportHandle? handle
---@return string? err
function M.tcp.connect(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    if vim.uv == nil then
        return nil, 'vim.uv is unavailable'
    end
    local host = opts.host
    local port = opts.port
    if type(host) ~= 'string' or host == '' then
        return nil, 'tcp transport needs opts.host'
    end
    if type(port) ~= 'number' or port < 1 or port > 65535 then
        return nil, 'tcp transport needs opts.port in 1..65535'
    end
    local sock = vim.uv.new_tcp()
    if sock == nil then
        return nil, 'could not create tcp handle'
    end
    local ok, err = await_connect(function(done)
        sock:connect(host, port, function(connect_err)
            done(connect_err)
        end)
    end)
    if not ok then
        pcall(sock.close, sock)
        return nil, 'tcp ' .. host .. ':' .. tostring(port) .. ': ' .. tostring(err)
    end
    return wrap_stream(sock), nil
end

---TLS transport (priority 2, secure tier). Stub: fails loudly.
---Follow-up: vim.uv has no TLS; a real implementation needs an
---external TLS terminator or a new uv-based TLS binding. Plaintext
---is never used as a silent fallback.
M.tls = {}
---@param opts PhlowTransportOpts
---@return PhlowTransportHandle? handle
---@return string? err
function M.tls.connect(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    return nil, 'tls transport not implemented: vim.uv has no TLS support (follow-up)'
end

---WebSocket transport (priority 3). Reuses the repo's websocket client.
---Needs opts.url as ws://host:port/path. wss:// is rejected (needs TLS).
M.websocket = {}
---@param opts PhlowTransportOpts
---@return PhlowTransportHandle? handle
---@return string? err
function M.websocket.connect(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    if vim.uv == nil then
        return nil, 'vim.uv is unavailable'
    end
    local url = opts.url
    if type(url) ~= 'string' or url == '' then
        return nil, 'websocket transport needs opts.url'
    end
    if url:sub(1, 6) == 'wss://' then
        return nil, 'wss:// needs TLS, which vim.uv does not provide (follow-up)'
    end
    local ok_mod, ws = pcall(require, 'websocket')
    if not ok_mod then
        return nil, 'websocket module unavailable: ' .. tostring(ws)
    end
    ws.setup()
    local ok_client, client_mod = pcall(require, 'websocket.client')
    if not ok_client then
        return nil, 'websocket.client unavailable: ' .. tostring(client_mod)
    end
    ---@type PhlowTransportHandle
    local handle = { _closed = false, _on_data = nil }
    local connected = false
    local ws_client = client_mod.WebsocketClient.new({
        connect_addr = url,
        on_message = function(_, message)
            local fn = handle._on_data
            if not handle._closed and fn ~= nil then
                fn(message .. '\n') -- one frame per message; keep NDJSON framing
            end
        end,
        on_connect = function()
            connected = true
        end,
        on_disconnect = function()
            connected = false
        end,
    })
    ws_client:try_connect()
    local done = vim.wait(M.CONNECT_TIMEOUT_MS, function()
        return connected or ws_client.closed
    end, 50)
    if done ~= true or not connected then
        ws_client:try_disconnect()
        return nil, 'websocket ' .. url .. ': handshake did not complete'
    end
    function handle:send(data)
        assert(type(data) == 'string', 'data must be a string')
        if self._closed then
            return nil, 'transport is closed'
        end
        return ws_client:try_send_data(data)
    end
    function handle:on_data(fn)
        assert(type(fn) == 'function', 'fn must be a function')
        self._on_data = fn
    end
    function handle:close()
        if self._closed then
            return
        end
        self._closed = true
        self._on_data = nil
        ws_client:try_disconnect()
    end
    return handle, nil
end

return M
