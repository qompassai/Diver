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

local frame = require('ai.websocket.frame')

-- Reconnect and queue bounds. All limits are named here so a caller can
-- reason about worst-case memory and retry behavior without reading code.
local RECONNECT_BASE_MS = 1000 -- first retry delay
local RECONNECT_BACKOFF_FACTOR = 2 -- delay doubles per attempt
local RECONNECT_MAX_DELAY_MS = 30000 -- delay cap
local DEFAULT_MAX_RECONNECT_ATTEMPTS = 10 -- then give up with on_error
local SEND_QUEUE_MAX_MESSAGES = 512 -- outbound queue message cap
local SEND_QUEUE_MAX_BYTES = 1024 * 1024 -- outbound queue byte cap (1 MiB)

local M = {}

---@class WebsocketClientOpts
---@field connect_addr string 'ws://host:port/path'
---@field on_message fun(self: WebsocketClient, message: string)
---@field on_connect? fun(self: WebsocketClient)
---@field on_disconnect? fun(self: WebsocketClient)
---@field on_error? fun(self: WebsocketClient, err: string)
---@field extra_headers? table<string, string>
---@field reconnect? boolean auto-reconnect on unexpected close; default true
---@field max_reconnect_attempts? integer give up after this many; default 10
---@field queue_max_messages? integer outbound queue cap; default 512

---@class WebsocketClient
---@field client_id string
---@field connect_addr string
---@field close fun(self: WebsocketClient) alias for try_disconnect
---@field auto_reconnect boolean
---@field max_reconnect_attempts integer
---@field queue_max_messages integer
---@field send_queue string[]
---@field queue_bytes integer
---@field queue_drops integer
---@field reconnect_attempts integer
---@field reconnect_timer userdata?
---@field intentional_close boolean
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
    local max_attempts = opts.max_reconnect_attempts or DEFAULT_MAX_RECONNECT_ATTEMPTS
    assert(type(max_attempts) == 'number' and max_attempts >= 0, 'max_reconnect_attempts must be a non-negative number')
    local queue_max = opts.queue_max_messages or SEND_QUEUE_MAX_MESSAGES
    assert(type(queue_max) == 'number' and queue_max >= 1, 'queue_max_messages must be a positive number')
    client_seq = client_seq + 1
    return setmetatable({
        client_id = 'client-' .. client_seq,
        connect_addr = opts.connect_addr,
        extra_headers = opts.extra_headers or {},
        on_message = opts.on_message,
        on_connect = opts.on_connect,
        on_disconnect = opts.on_disconnect,
        on_error = opts.on_error,
        auto_reconnect = opts.reconnect ~= false,
        max_reconnect_attempts = max_attempts,
        queue_max_messages = queue_max,
        send_queue = {},
        queue_bytes = 0,
        queue_drops = 0,
        reconnect_attempts = 0,
        reconnect_timer = nil,
        intentional_close = false,
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

---Stop the socket and reset connection state, without firing callbacks.
---Shared by failure, remote-close, and reconnect paths so handles are
---owned and released in exactly one place.
function WebsocketClient:_teardown_socket()
    self.handshake_done = false
    self.http_buf = ''
    self.decoder = frame.Decoder.new()
    ActiveClients[self.client_id] = nil
    if self.sock ~= nil then
        local sock = self.sock
        self.sock = nil
        if not sock:is_closing() then
            sock:close()
        end
    end
end

---Cancel a pending reconnect timer, if any. Safe to call when idle.
function WebsocketClient:_cancel_reconnect()
    local timer = self.reconnect_timer
    self.reconnect_timer = nil
    if timer ~= nil and not timer:is_closing() then
        timer:stop()
        timer:close()
    end
end

---Schedule another connect attempt with exponential backoff.
---Gives up after max_reconnect_attempts and surfaces on_error once.
---@param err string the failure that triggered this attempt
function WebsocketClient:_schedule_reconnect(err)
    if self.intentional_close or self.closed then
        return
    end
    self.reconnect_attempts = self.reconnect_attempts + 1
    if self.reconnect_attempts > self.max_reconnect_attempts then
        self.closed = true
        if self.on_error ~= nil then
            self.on_error(self, 'reconnect attempts exhausted (' .. self.max_reconnect_attempts .. '): ' .. err)
        end
        return
    end
    self:_cancel_reconnect()
    local delay = math.min(
        RECONNECT_BASE_MS * (RECONNECT_BACKOFF_FACTOR ^ (self.reconnect_attempts - 1)),
        RECONNECT_MAX_DELAY_MS
    )
    local timer = vim.uv.new_timer()
    if timer == nil then
        self.closed = true
        if self.on_error ~= nil then
            self.on_error(self, 'cannot create reconnect timer: ' .. err)
        end
        return
    end
    self.reconnect_timer = timer
    local self_ref = self
    timer:start(delay, 0, function()
        -- Recheck freshness: only the current timer may fire.
        if self_ref.reconnect_timer ~= timer then
            return
        end
        self_ref.reconnect_timer = nil
        if not timer:is_closing() then
            timer:stop()
            timer:close()
        end
        if self_ref.intentional_close or self_ref.closed then
            return
        end
        self_ref:try_connect()
    end)
end

---Report an error, then tear down. When auto-reconnect is on and the
---shutdown was not intentional, schedule a retry instead of closing;
---on_error fires once, only when attempts are exhausted or disabled.
---@param err string
function WebsocketClient:_fail(err)
    if self.closed then
        return
    end
    self:_teardown_socket()
    if self.auto_reconnect and not self.intentional_close then
        self:_schedule_reconnect(err)
        return
    end
    self.closed = true
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
    self.reconnect_attempts = 0
    ActiveClients[self.client_id] = { id = self.client_id, connect_addr = self.connect_addr }
    if self.on_connect ~= nil then
        self.on_connect(self)
    end
    self:_flush_queue()
    return true
end

---Send everything queued while disconnected, in order.
function WebsocketClient:_flush_queue()
    local queue = self.send_queue
    self.send_queue = {}
    self.queue_bytes = 0
    for i = 1, #queue do
        if self.sock ~= nil then
            self.sock:write(frame.encode_text(queue[i], true))
        end
    end
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

---The server closed the connection (EOF or close frame), or we shut down.
---Unexpected closes auto-reconnect when enabled; an explicit close()
---never reconnects. on_disconnect fires exactly once per connection loss.
function WebsocketClient:_close_remote()
    if self.closed then
        return
    end
    local was_intentional = self.intentional_close
    self:_teardown_socket()
    if self.on_disconnect ~= nil then
        self.on_disconnect(self)
    end
    if self.auto_reconnect and not was_intentional then
        self:_schedule_reconnect('connection closed by remote')
        return
    end
    self.closed = true
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
    self:_cancel_reconnect()
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

---Send a text message. While disconnected the message is queued for
---delivery on the next successful connect, bounded by queue_max_messages
---and SEND_QUEUE_MAX_BYTES; overflow drops the oldest and counts drops.
---Returns nil plus an error string when closed or over the byte cap.
---@param data string
---@return boolean? ok
---@return string? err
function WebsocketClient:try_send_data(data)
    assert(type(data) == 'string', 'data must be a string')
    if self.closed or self.intentional_close then
        return nil, 'client is closed'
    end
    if self:is_active() then
        self.sock:write(frame.encode_text(data, true))
        return true, nil
    end
    while #self.send_queue > 0
        and (#self.send_queue >= self.queue_max_messages or self.queue_bytes + #data > SEND_QUEUE_MAX_BYTES) do
        local oldest = table.remove(self.send_queue, 1)
        self.queue_bytes = self.queue_bytes - #oldest
        self.queue_drops = self.queue_drops + 1
    end
    if #self.send_queue >= self.queue_max_messages or self.queue_bytes + #data > SEND_QUEUE_MAX_BYTES then
        -- A single message larger than the byte cap can never be queued.
        self.queue_drops = self.queue_drops + 1
        return nil, 'message exceeds queue byte cap'
    end
    self.send_queue[#self.send_queue + 1] = data
    self.queue_bytes = self.queue_bytes + #data
    return true, nil
end

---Current lifecycle state: 'connected', 'connecting', 'reconnecting',
---'idle' (never connected and no attempt pending), or 'closed'.
---@return string
function WebsocketClient:state()
    if self.closed or self.intentional_close then
        return 'closed'
    end
    if self.reconnect_timer ~= nil then
        return 'reconnecting'
    end
    if self.sock ~= nil then
        if self.handshake_done then
            return 'connected'
        end
        return 'connecting'
    end
    return 'idle'
end

---How many outbound messages are waiting for the next connect.
---@return integer
function WebsocketClient:pending_messages()
    return #self.send_queue
end

---How many queued outbound messages were dropped (overflow or close).
---@return integer
function WebsocketClient:dropped_messages()
    return self.queue_drops
end

---Close the connection gracefully. Idempotent: timers are cancelled,
---queued messages are dropped and counted, handles released, and
---on_disconnect fires at most once. Never reconnects afterwards.
function WebsocketClient:try_disconnect()
    if self.intentional_close then
        return
    end
    self.intentional_close = true
    self:_cancel_reconnect()
    self.queue_drops = self.queue_drops + #self.send_queue
    self.send_queue = {}
    self.queue_bytes = 0
    if self.sock ~= nil and self.handshake_done then
        self.sock:write(frame.encode('', frame.OPCODE_CLOSE, true))
    end
    self:_close_remote()
end

---Alias for try_disconnect.
WebsocketClient.close = WebsocketClient.try_disconnect

return M
