-- Purpose: WebSocket transport for BiDi, adapted over
-- ai.websocket.client. Reconnect is forced OFF: a dropped BiDi socket
-- invalidates the whole session, so a silent reconnect would hand the
-- caller a dead session id. The URL must be ws:// on loopback; anything
-- else is refused before any socket exists.

local ws_client_mod = require('ai.websocket.client')

local M = {}

local LOOPBACK_HOSTS = {
    ['127.0.0.1'] = true,
    ['::1'] = true,
    ['localhost'] = true,
}

---@class BidiTransport
---@field _client any underlying WebsocketClient
---@field url string
---@field closed boolean

---Validate a BiDi WebSocket URL. Pure; no I/O. Returns the normalized
---ws:// URL or (nil, err).
---@param url string
---@return string? ok_url
---@return string? err
function M._validate_url(url)
    if type(url) ~= 'string' then
        return nil, 'websocket url must be a string'
    end
    local host, port, path = url:match('^ws://([^:/%[%]]+):(%d+)(/?.*)$')
    if host == nil then
        -- bracketed IPv6 literal, e.g. ws://[::1]:9515/session
        host, port, path = url:match('^ws://%[([^%]]+)%]:(%d+)(/?.*)$')
    end
    if host == nil then
        return nil, 'websocket url must look like ws://host:port/path: ' .. url:sub(1, 80)
    end
    if LOOPBACK_HOSTS[host] ~= true then
        return nil, 'bidi: non-loopback webSocketUrl refused (policy: localhost-only): ' .. host
    end
    if path == '' then
        path = '/'
    end
    return 'ws://' .. host .. ':' .. port .. path, nil
end

---@class BidiTransportOpts
---@field on_text fun(text: string) wire.on_text entry point
---@field on_connect? fun()
---@field on_disconnect? fun() session is dead; fail pending commands
---@field on_error? fun(err: string)

---Connect. on_disconnect means the session is invalid; the caller must
---fail_all its wire state. Never reconnects.
---@param url string webSocketUrl from the driver
---@param opts BidiTransportOpts
---@return BidiTransport? transport
---@return string? err
function M._connect_raw(url, opts)
    assert(type(opts) == 'table', 'opts must be a table')
    assert(type(opts.on_text) == 'function', 'opts.on_text must be a function')
    local addr, uerr = M._validate_url(url)
    if addr == nil then
        return nil, uerr
    end
    local transport = { url = addr, closed = false, _client = nil }
    local client = ws_client_mod.WebsocketClient.new({
        connect_addr = addr,
        reconnect = false, -- a dropped BiDi socket invalidates the session
        on_message = function(_, message)
            if not transport.closed then
                opts.on_text(message)
            end
        end,
        on_connect = function(_)
            if opts.on_connect ~= nil and not transport.closed then
                opts.on_connect()
            end
        end,
        on_disconnect = function(_)
            if opts.on_disconnect ~= nil then
                opts.on_disconnect()
            end
        end,
        on_error = function(_, err)
            if opts.on_error ~= nil then
                opts.on_error(err)
            end
        end,
    })
    transport._client = client
    client:try_connect()
    M._attach(transport)
    return transport, nil
end

---Wrapped connect kept under the public name.
---@param url string
---@param opts BidiTransportOpts
---@return BidiTransport?
---@return string?
function M.connect(url, opts)
    return M._connect_raw(url, opts)
end

---Send one text frame. Returns (nil, err) when closed or not connected.
---@param self BidiTransport
---@param text string
---@return boolean? ok
---@return string? err
local function send_text(self, text)
    assert(type(text) == 'string', 'text must be a string')
    if self.closed then
        return nil, 'transport is closed'
    end
    return self._client:try_send_data(text)
end

---True once the handshake completed and the socket is open.
---@param self BidiTransport
---@return boolean
local function is_active(self)
    return not self.closed and self._client:is_active()
end

---Close the socket. Idempotent; never reconnects afterwards.
---@param self BidiTransport
local function close(self)
    if self.closed then
        return
    end
    self.closed = true
    self._client:try_disconnect()
end

---Attach methods. Kept as a constructor helper so tests can build a
---transport-shaped table without a socket.
---@param transport BidiTransport
function M._attach(transport)
    transport.send_text = send_text
    transport.is_active = is_active
    transport.close = close
end

return M
