-- /qompassai/Diver/lua/websocket/server.lua
-- Native WebSocket server over vim.uv TCP (no FFI, no external plugin).
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this listens on a TCP port, shakes hands with each
-- WebSocket client that connects, and routes their messages to your
-- callbacks. You can reply to one client or broadcast to all.
-- Everything is non-blocking: callbacks fire on Neovim's main loop.
---@module 'websocket.server'

local frame = require('websocket.frame')

local M = {}

---@class WebsocketServerOpts
---@field host string bind address, e.g. '127.0.0.1'
---@field port integer bind port
---@field on_message fun(self: WebsocketServer, client_id: string, message: string)
---@field on_client_connect? fun(self: WebsocketServer, client_id: string)
---@field on_client_disconnect? fun(self: WebsocketServer, client_id: string)
---@field on_error? fun(self: WebsocketServer, err: string)
---@field extra_response_headers? table<string, string>

---@class WebsocketServer
local WebsocketServer = {}
WebsocketServer.__index = WebsocketServer
M.WebsocketServer = WebsocketServer

---@type table<WebsocketServer, boolean>
local ActiveServers = {}

---Create a server. Does not bind yet; call try_start().
---@param opts WebsocketServerOpts
---@return WebsocketServer
function WebsocketServer.new(opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.port) == 'number', 'port must be a number')
    assert(type(opts.on_message) == 'function', 'on_message must be a function')
    local host = opts.host or '127.0.0.1'
    if host == 'localhost' then
        host = '127.0.0.1'
    end
    return setmetatable({
        host = host,
        port = opts.port,
        extra_response_headers = opts.extra_response_headers or {},
        on_message = opts.on_message,
        on_client_connect = opts.on_client_connect,
        on_client_disconnect = opts.on_client_disconnect,
        on_error = opts.on_error,
        listen_sock = nil,
        ---@type table<string, table> client_id -> { sock, handshake_done, http_buf, decoder }
        clients = {},
        client_seq = 0,
        closed = false,
    }, WebsocketServer)
end

---All currently listening servers.
---@return table<WebsocketServer, boolean>
function WebsocketServer.get_servers()
    local out = {}
    for server in pairs(ActiveServers) do
        out[server] = true
    end
    return out
end

---Report a server-level error.
---@param err string
function WebsocketServer:_fail(err)
    if self.on_error ~= nil then
        self.on_error(self, err)
    end
end

---Drop one client: close its socket and notify.
---@param client_id string
function WebsocketServer:_drop_client(client_id)
    local client = self.clients[client_id]
    if client == nil then
        return
    end
    self.clients[client_id] = nil
    if client.sock ~= nil then
        local sock = client.sock
        client.sock = nil
        sock:close()
    end
    if self.on_client_disconnect ~= nil then
        self.on_client_disconnect(self, client_id)
    end
end

---Answer the HTTP upgrade request and mark the client connected.
---@param client_id string
---@param header string raw request header block
---@return boolean ok
function WebsocketServer:_finish_handshake(client_id, header)
    local client = self.clients[client_id]
    local key = frame.parse_headers(header)['sec-websocket-key']
    if key == nil or key == '' then
        return false
    end
    local response = table.concat({
        'HTTP/1.1 101 Switching Protocols',
        'Upgrade: websocket',
        'Connection: Upgrade',
        'Sec-WebSocket-Accept: ' .. frame.accept_key(key),
    }, '\r\n')
    for name, value in pairs(self.extra_response_headers) do
        response = response .. '\r\n' .. name .. ': ' .. value
    end
    response = response .. '\r\n\r\n'
    client.sock:write(response)
    client.handshake_done = true
    if self.on_client_connect ~= nil then
        self.on_client_connect(self, client_id)
    end
    return true
end

---Handle one decoded frame event from a client.
---@param client_id string
---@param event { opcode: integer, payload: string }
function WebsocketServer:_on_event(client_id, event)
    local client = self.clients[client_id]
    if client == nil then
        return
    end
    if event.opcode == frame.OPCODE_CLOSE then
        self:_drop_client(client_id)
    elseif event.opcode == frame.OPCODE_PING then
        client.sock:write(frame.encode(event.payload, frame.OPCODE_PONG, false))
    elseif event.opcode == frame.OPCODE_TEXT or event.opcode == frame.OPCODE_BINARY then
        self.on_message(self, client_id, event.payload)
    end
end

---Feed received bytes through the handshake or the frame decoder.
---@param client_id string
---@param chunk string
function WebsocketServer:_on_bytes(client_id, chunk)
    local client = self.clients[client_id]
    if client == nil then
        return
    end
    if not client.handshake_done then
        client.http_buf = client.http_buf .. chunk
        if #client.http_buf > 8192 then
            self:_drop_client(client_id)
            return
        end
        local eoh = client.http_buf:find('\r\n\r\n', 1, true)
        if eoh == nil then
            return
        end
        local header = client.http_buf:sub(1, eoh + 3)
        local rest = client.http_buf:sub(eoh + 4)
        client.http_buf = ''
        if not self:_finish_handshake(client_id, header) then
            self:_drop_client(client_id)
            return
        end
        if #rest > 0 then
            self:_on_bytes(client_id, rest)
        end
        return
    end
    local events, err = client.decoder:feed(chunk)
    if events == nil then
        self:_fail('frame error: ' .. err)
        self:_drop_client(client_id)
        return
    end
    for _, event in ipairs(events) do
        self:_on_event(client_id, event)
    end
end

---Accept one inbound TCP connection.
function WebsocketServer:_accept()
    local sock = vim.uv.new_tcp()
    local ok = self.listen_sock:accept(sock)
    if not ok then
        sock:close()
        return
    end
    self.client_seq = self.client_seq + 1
    local client_id = 'peer-' .. self.client_seq
    self.clients[client_id] = {
        sock = sock,
        handshake_done = false,
        http_buf = '',
        decoder = frame.Decoder.new(),
    }
    local self_ref = self
    sock:read_start(function(err, chunk)
        if err ~= nil then
            self_ref:_drop_client(client_id)
            return
        end
        if chunk == nil then
            self_ref:_drop_client(client_id)
            return
        end
        self_ref:_on_bytes(client_id, chunk)
    end)
end

---Bind and start listening. Reports failures through on_error.
function WebsocketServer:try_start()
    assert(not self.closed, 'server is closed')
    assert(self.listen_sock == nil, 'server already started')
    local sock = vim.uv.new_tcp()
    local ok, err = sock:bind(self.host, self.port)
    if not ok then
        sock:close()
        self:_fail('bind failed: ' .. tostring(err))
        return
    end
    local self_ref = self
    sock:listen(128, function(listen_err)
        if listen_err ~= nil then
            self_ref:_fail('accept failed: ' .. listen_err)
            return
        end
        self_ref:_accept()
    end)
    self.listen_sock = sock
    ActiveServers[self] = true
end

---True while the server is listening.
---@return boolean
function WebsocketServer:is_active()
    return self.listen_sock ~= nil and not self.closed
end

---Send a text message to one client. Returns nil plus error when unknown.
---@param client_id string
---@param data string
---@return boolean? ok
---@return string? err
function WebsocketServer:try_send_data_to_client(client_id, data)
    assert(type(data) == 'string', 'data must be a string')
    local client = self.clients[client_id]
    if client == nil or not client.handshake_done then
        return nil, 'unknown or unready client'
    end
    client.sock:write(frame.encode_text(data, false))
    return true, nil
end

---Send a text message to every connected client.
---@param data string
function WebsocketServer:try_broadcast_data_to_clients(data)
    assert(type(data) == 'string', 'data must be a string')
    for client_id in pairs(self.clients) do
        self:try_send_data_to_client(client_id, data)
    end
end

---Disconnect one client.
---@param client_id string
function WebsocketServer:try_disconnect_client(client_id)
    local client = self.clients[client_id]
    if client ~= nil and client.handshake_done and client.sock ~= nil then
        client.sock:write(frame.encode('', frame.OPCODE_CLOSE, false))
    end
    self:_drop_client(client_id)
end

---Stop listening and drop all clients.
function WebsocketServer:try_stop()
    if self.closed then
        return
    end
    self.closed = true
    ActiveServers[self] = nil
    for client_id in pairs(self.clients) do
        self:_drop_client(client_id)
    end
    if self.listen_sock ~= nil then
        local sock = self.listen_sock
        self.listen_sock = nil
        sock:close()
    end
end

return M
