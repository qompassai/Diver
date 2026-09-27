-- /qompassai/Diver/lua/phlow/init.lua
-- Public surface of the versioned Phlow API client (presentation side).
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: this is the front door. You call connect() with where
-- Phlow lives, and you get back a clerk (client) who can send commands
-- and listen for announcements. It knocks on each door in order --
-- unix socket first, then TCP/TLS, then WebSocket -- and uses the
-- first one that opens. Diver owns presentation here: this client
-- carries no orchestration state and no workflow engine.
---@module 'phlow'

local M = {}

---Versioned API version (string, per the Phlow architecture doc).
M.API_VERSION = '1'

---Alias for the doc's PHLOW_API_VERSION naming; same string.
M.PHLOW_API_VERSION = M.API_VERSION

---@class PhlowConnectOpts
---@field unix_path? string unix socket path (tried first)
---@field host? string tcp/tls host
---@field port? integer tcp/tls port
---@field use_tls? boolean require TLS on the tcp tier (never silently downgraded)
---@field websocket_url? string ws:// url (tried last; wss:// needs TLS)
---@field timeout_ms? integer per-request timeout for the client

---Connect to Phlow, trying transports in priority order:
---unix socket -> tcp/tls -> websocket. First success wins.
---@param opts? PhlowConnectOpts
---@return PhlowClient? client
---@return string? err
function M.connect(opts)
    opts = opts or {}
    assert(type(opts) == 'table', 'opts must be a table')
    local transports = require('ai.phlow.transports')
    local errors = {}
    local handle = nil
    local function attempt(name, connect_fn, topts)
        local h, err = connect_fn(topts)
        if h ~= nil then
            return h
        end
        errors[#errors + 1] = name .. ': ' .. tostring(err)
        return nil
    end
    if opts.unix_path ~= nil then
        handle = attempt('unix', transports.unix.connect, { path = opts.unix_path })
    end
    if handle == nil and opts.host ~= nil then
        if opts.use_tls then
            handle = attempt('tls', transports.tls.connect, { host = opts.host, port = opts.port })
        else
            handle = attempt('tcp', transports.tcp.connect, { host = opts.host, port = opts.port })
        end
    end
    if handle == nil and opts.websocket_url ~= nil then
        handle = attempt('websocket', transports.websocket.connect, { url = opts.websocket_url })
    end
    if handle == nil then
        if #errors == 0 then
            return nil, 'no transport configured: set unix_path, host/port, or websocket_url'
        end
        return nil, 'all transports failed: ' .. table.concat(errors, '; ')
    end
    local client = require('ai.phlow.client')
    return client.new(handle, { timeout_ms = opts.timeout_ms }), nil
end

return M
