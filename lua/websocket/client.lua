-- /qompassai/Diver/lua/websocket/client.lua
-- Native WebSocket client over vim.uv TCP (no FFI, no external plugin).
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this opens a real WebSocket connection to a server
-- using only Neovim's built-in networking. You give it an address
-- like ws://localhost:12001 plus callbacks for messages, connect,
-- disconnect, and errors; it handles the HTTP handshake and the
-- binary message envelopes for you. Everything is non-blocking:
-- callbacks fire on Neovim's main loop.
---@module 'websocket.client'

local frame = require('websocket.frame')

local M = {}

---@class WebsocketClientOpts
---@field connect_addr string 'ws://host:port/path'
---@field on_message fun(self: WebsocketClient, message: string)
---@field on_connect? fun(self: WebsocketClient)
---@field on_disconnect? fun(self: WebsocketClient)
---@field on_error? fun(self: WebsocketClient, err: string)
---@field extra_headers? table<string, string>

---@class WebsocketClient
---@field client_id string
---@field connect_addr string
local WebsocketClient = {}
WebsocketClient.__index = WebsocketClient
M.WebsocketClient = WebsocketClient

---@type table<string, { id: string, connect_addr: string }>
local ActiveClients = {}
local client_seq = 0

---Create a client. Does not connect yet; call try_connect().
---@param opts WebsocketClientOpts
---@return WebsocketClient
function WebsocketClient.new(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.connect_addr) == 'string', 'connect_addr must be a string')
    assert(type(opts.on_message) == 'function', 'on_message must be a function')
    client_seq = client_seq + 1
    return setmetatable({
        client_id = 'client-' .. client_seq,
        connect_addr = opts.connect_addr,
        extra_headers = opts.extra_headers or {},
        on_message = opts.on_message,
        on_connect = opts.on_connect,
        on_disconnect = opts.on_disconnect,
        on_error = opts.on_error,
        sock = nil,
        handshake_done = false,
        http_buf = '',
        decoder = frame.Decoder.new(),
        closed = false,
    }, WebsocketClient)
end

---All currently connected clients, keyed by client id.
---@return table<string, { id: string, connect_addr: string }>
function WebsocketClient.get_clients()
    local out = {}
    for id, info in pairs(ActiveClients) do
        out[id] = info
    end
    return out
end

---Parse 'ws://host:port/path'. Returns host, port, path or nil.
---@param addr string
---@return string? host
---@return integer? port
---@return string? path
local function parse_addr(addr)
    local host, port, path = addr:match('^ws://([^:/]+):(%d+)(/?.*)$')
    if host == nil then
        return nil
    end
    if host == 'localhost' then
        host = '127.0.0.1'
    end
    if path == '' then
        path = '/'
    end
    return host, tonumber(port), path
end

---16 random bytes, base64-encoded, for the handshake key.
---@return string
local function new_key()
    local bytes = {}
    for i = 1, 16 do
        bytes[i] = string.char(math.random(0, 255))
    end
    return vim.base64.encode(table.concat(bytes))
end

---Report an error, then tear down. The error callback fires at most once.
---@param err string
function WebsocketClient:_fail(err)
    if self.closed then
        return
    end
    self.closed = true
    ActiveClients[self.client_id] = nil
    if self.sock ~= nil then
        local sock = self.sock
        self.sock = nil
        sock:close()
    end
    if self.on_error ~= nil then
        self.on_error(self, err)
    end
end

---Finish the HTTP handshake. Returns false when the server answer is bad.
---@param header string raw response header block
---@return boolean ok
function WebsocketClient:_finish_handshake(header)
    local status = header:match('^HTTP/%S+ (%d+)')
    local accept = frame.parse_headers(header)['sec-websocket-accept']
    if status ~= '101' or accept == nil then
        self:_fail('handshake rejected by server')
        return false
    end
    if accept ~= frame.accept_key(self._key) then
        self:_fail('handshake accept key mismatch')
        return false
    end
    self.handshake_done = true
    ActiveClients[self.client_id] = { id = self.client_id, connect_addr = self.connect_addr }
    if self.on_connect ~= nil then
        self.on_connect(self)
    end
    return true
end

---Handle one decoded frame event.
---@param event { opcode: integer, payload: string }
function WebsocketClient:_on_event(event)
    if event.opcode == frame.OPCODE_CLOSE then
        self:_close_remote()
    elseif event.opcode == frame.OPCODE_PING then
        if self.sock ~= nil then
            self.sock:write(frame.encode(event.payload, frame.OPCODE_PONG, true))
        end
    elseif event.opcode == frame.OPCODE_TEXT or event.opcode == frame.OPCODE_BINARY then
        self.on_message(self, event.payload)
    end
end

---Feed received bytes through the handshake or the frame decoder.
---@param chunk string
function WebsocketClient:_on_bytes(chunk)
    if not self.handshake_done then
        self.http_buf = self.http_buf .. chunk
        if #self.http_buf > 8192 then
            self:_fail('handshake header too large')
            return
        end
        local eoh = self.http_buf:find('\r\n\r\n', 1, true)
        if eoh == nil then
            return
        end
        local header = self.http_buf:sub(1, eoh + 3)
        local rest = self.http_buf:sub(eoh + 4)
        self.http_buf = ''
        if not self:_finish_handshake(header) then
            return
        end
        if #rest > 0 then
            self:_on_bytes(rest)
        end
        return
    end
    local events, err = self.decoder:feed(chunk)
    if events == nil then
        self:_fail(err)
        return
    end
    for _, event in ipairs(events) do
        self:_on_event(event)
    end
end

---The server closed the connection (EOF or close frame).
function WebsocketClient:_close_remote()
    if self.closed then
        return
    end
    self.closed = true
    ActiveClients[self.client_id] = nil
    if self.sock ~= nil then
        local sock = self.sock
        self.sock = nil
        sock:close()
    end
    if self.on_disconnect ~= nil then
        self.on_disconnect(self)
    end
end

---Read callback from libuv.
---@param err string?
---@param chunk string?
function WebsocketClient:_on_data(err, chunk)
    if self.closed then
        return
    end
    if err ~= nil then
        self:_fail('read error: ' .. err)
        return
    end
    if chunk == nil then
        self:_close_remote()
        return
    end
    self:_on_bytes(chunk)
end

---Connect to the server and run the WebSocket handshake.
function WebsocketClient:try_connect()
    assert(not self.closed, 'client is closed')
    assert(self.sock == nil, 'already connecting or connected')
    local host, port, path = parse_addr(self.connect_addr)
    if host == nil then
        self:_fail('invalid connect_addr: ' .. self.connect_addr)
        return
    end
    self._key = new_key()
    local sock = vim.uv.new_tcp()
    self.sock = sock
    local request = table.concat({
        'GET ' .. path .. ' HTTP/1.1',
        'Host: ' .. host .. ':' .. port,
        'Upgrade: websocket',
        'Connection: Upgrade',
        'Sec-WebSocket-Key: ' .. self._key,
        'Sec-WebSocket-Version: 13',
    }, '\r\n')
    for name, value in pairs(self.extra_headers) do
        request = request .. '\r\n' .. name .. ': ' .. value
    end
    request = request .. '\r\n\r\n'
    local self_ref = self
    sock:connect(host, port, function(connect_err)
        if connect_err ~= nil then
            self_ref:_fail('connect failed: ' .. connect_err)
            return
        end
        sock:write(request)
        sock:read_start(function(read_err, chunk)
            self_ref:_on_data(read_err, chunk)
        end)
    end)
end

---True once the handshake completed and the socket is open.
---@return boolean
function WebsocketClient:is_active()
    return self.handshake_done and not self.closed
end

---Send a text message. Returns nil plus an error string when not connected.
---@param data string
---@return boolean? ok
---@return string? err
function WebsocketClient:try_send_data(data)
    assert(type(data) == 'string', 'data must be a string')
    if not self:is_active() then
        return nil, 'client is not connected'
    end
    self.sock:write(frame.encode_text(data, true))
    return true, nil
end

---Close the connection gracefully.
function WebsocketClient:try_disconnect()
    if self.closed then
        return
    end
    if self.sock ~= nil and self.handshake_done then
        self.sock:write(frame.encode('', frame.OPCODE_CLOSE, true))
    end
    self:_close_remote()
end

return M
