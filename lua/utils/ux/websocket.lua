#!/usr/bin/env lua
--- WebSocket client wrapper — open live-updating socket connections (FFI bridge).
---
--- Plain-language version: this module wraps a native (Rust) WebSocket client
--- through an FFI bridge so Neovim can keep a live connection to a service.
--- The bridge is not initialized in this configuration, so the module loads
--- as a fail-closed stub: requiring it never fails, but every use raises a
--- clear "unavailable" error.
---@module 'utils.ux.websocket'

-- websocket.lua
-- Qompass AI - [ ]
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
if _G['_WEBSOCKET_NVIM'] == nil then
    -- The websocket FFI bridge is not initialized in this session: the
    -- `_WEBSOCKET_NVIM` runtime state is absent and the `websocket_ffi`
    -- native module is not installed. Degrade gracefully instead of erroring
    -- at require time, but stay fail-closed: requiring this module never
    -- fails, yet constructing or using a client raises a clear error, so
    -- nothing silently pretends to work.
    local function client_unavailable()
        error('utils.ux.websocket unavailable: websocket FFI bridge not initialized', 2)
    end
    --- Stub client class: construction and every method fail closed.
    local WebsocketClientStub = {}
    function WebsocketClientStub.new(_opts)
        client_unavailable()
    end
    setmetatable(WebsocketClientStub, {
        __index = function(_, _)
            return client_unavailable
        end,
    })
    return {
        WebsocketClient = WebsocketClientStub,
        ErrorType = {
            ConnectionError = 'connection_error',
            DisconnectionError = 'disconnection_error',
            ReceiveMessageError = 'receive_message_error',
            SendMessageError = 'send_message_error',
        },
    }
end

local websocket_client_ffi = require('websocket_ffi').client
local uuid_utils = require('utils.uuid')

local M = {}

---@class WebsocketClient
---@field client_id string
---@field connect_addr string
---@field extra_headers table<string, string>
---@field on_message fun(self: WebsocketClient, message: string)
---@field on_disconnect? fun(self: WebsocketClient)
---@field on_connect? fun(self: WebsocketClient)
---@field on_error? fun(self: WebsocketClient, err: WebsocketClientError)
local WebsocketClient = {}
WebsocketClient.__index = WebsocketClient
WebsocketClient.__is_class = true
M.WebsocketClient = WebsocketClient

---@type table<string, WebsocketClient>
local WebsocketClientMap = {}

---@enum WebsocketClientErrorType
local ErrorType = {
    ConnectionError = 'connection_error',
    DisconnectionError = 'disconnection_error',
    ReceiveMessageError = 'receive_message_error',
    SendMessageError = 'send_message_error',
}
M.ErrorType = ErrorType

---@alias WebsocketClientError { type: WebsocketClientErrorType, message: string }

---@class WebsocketClientOpts
---@field connect_addr string
---@field extra_headers? table<string, string>
---@field on_message fun(self: WebsocketClient, message: string)
---@field on_disconnect? fun(self: WebsocketClient)
---@field on_connect? fun(self: WebsocketClient)
---@field on_error? fun(self: WebsocketClient, err: WebsocketClientError)

-- Create a new websocket client
--
---@param opts WebsocketClientOpts
---@return WebsocketClient
function WebsocketClient.new(opts)
    local client_id = uuid_utils.v4()
    local obj = {
        client_id = client_id,
        connect_addr = opts.connect_addr,
        extra_headers = opts.extra_headers or {},
        on_message = opts.on_message,
        on_disconnect = opts.on_disconnect,
        on_connect = opts.on_connect,
        on_error = opts.on_error,
    }
    setmetatable(obj, WebsocketClient)
    WebsocketClientMap[client_id] = obj
    return obj
end

-- Connect to the websocket server
function WebsocketClient:try_connect()
    _G['_WEBSOCKET_NVIM'].clients.callbacks[self.client_id] = {
        on_message = function(client_id, message)
            local client = WebsocketClientMap[client_id]
            if not client then
                error('Received message but client not found', client_id)
            end

            if client.on_message then
                client.on_message(client, message)
            end
        end,
        on_disconnect = function(client_id)
            local client = WebsocketClientMap[client_id]
            if not client then
                error('Disconnected but client not found', client_id)
            end

            WebsocketClientMap[client_id] = nil

            if client.on_disconnect then
                client.on_disconnect(client)
            end
        end,
        on_connect = function(client_id)
            local client = WebsocketClientMap[client_id]
            if not client then
                error('Connected but client not found', client_id)
            end

            if client.on_connect then
                client.on_connect(client)
            end
        end,
        on_error = function(client_id, err)
            local client = WebsocketClientMap[client_id]
            if not client then
                error('Encounters error but client not found', client_id)
            end

            if client.on_error then
                client.on_error(client, err)
            end
        end,
    }
    websocket_client_ffi.connect(self.client_id, self.connect_addr, self.extra_headers)
end

-- Check if the websocket client is active
--
---@return boolean
function WebsocketClient:is_active()
    return WebsocketClient.get_clients()[self.client_id] ~= nil
end

-- Get all active websocket clients
--
---@return table<string, { id: string, connect_addr: string }>
function WebsocketClient.get_clients()
    local clients = websocket_client_ffi.get_clients()
    return clients
end

-- Send data to the websocket server
--
---@param data string
function WebsocketClient:try_send_data(data)
    websocket_client_ffi.send_data(self.client_id, data)
end

-- Disconnect from the websocket server
function WebsocketClient:try_disconnect()
    websocket_client_ffi.disconnect(self.client_id)
end

return M
