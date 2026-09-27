-- #################################################################
-- ~/workspace/repos/diver/lua/dap/integrations/phlow.lua
-- Qompass AI Diver Native Phlow DAP Integration
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---Thin presentation-side client for Phlow-brokered debug sessions.
---
---Per the Phlow architecture doc, Phlow owns orchestration state and Diver
---owns presentation: this module keeps no session state of its own, performs
---no retries beyond what the `phlow` client already does, and surfaces every
---failure as `(nil, err)`. The transport-pluggable `lua/phlow/` client is a
---sibling deliverable; this module assumes its contract and connects lazily.
---@source https://github.com/qompassai/phlow

local M = {}

local SOURCE = 'dap-phlow'

---@type string
---Canonical command name, per `phlow.schemas` (mirrors the Phlow
---`schemas/commands` contract). Do not invent variants.
local DEBUG_SESSION_CMD = 'debug.start'

---@type string
---Canonical event name, per `phlow.schemas` (mirrors the Phlow
---`schemas/events` contract).
local DEBUG_EVENT_NAME = 'debug.event'

---@type table?
local client = nil

---@param message string
---@param level? integer
local function notify(message, level)
    vim.notify(('[%s] %s'):format(SOURCE, message), level or vim.log.levels.INFO)
end

---@param value unknown
---@return boolean
local function nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@return table?, string?
---The `phlow` client module, validated to carry the versioned API contract
---this integration was written against. Returns `(nil, err)` when the
---sibling module is missing or its shape does not match.
local function load_phlow()
    local ok, phlow = pcall(require, 'phlow')

    if not ok or type(phlow) ~= 'table' then
        return nil, 'phlow client module is unavailable'
    end

    if not nonempty_string(phlow.API_VERSION) then
        return nil, 'phlow client does not expose a valid API_VERSION'
    end

    if type(phlow.connect) ~= 'function' then
        return nil, 'phlow client does not expose connect(opts)'
    end

    return phlow, nil
end

---@param opts? table
---@return table?, string?
---Connect to Phlow. Lazy: nothing connects at require time. Replaces any
---previously connected client after closing it exactly once.
function M.connect(opts)
    local phlow, load_err = load_phlow()

    if phlow == nil then
        return nil, load_err
    end

    local new_client, connect_err = phlow.connect(opts or {})

    if new_client == nil or type(new_client.request) ~= 'function' then
        return nil, connect_err or 'phlow.connect returned no usable client'
    end

    if client ~= nil and type(client.close) == 'function' then
        pcall(client.close, client)
    end

    client = new_client
    notify(('connected (phlow API %s)'):format(phlow.API_VERSION))
    return client, nil
end

---@param opts? table
---@return table?, string?
---Ask Phlow to broker a debug session and return the session info Phlow
---provides. Presentation only: no orchestration state is kept here.
function M.request_debug_session(opts)
    if client == nil then
        return nil, 'not connected: call connect() first'
    end

    local params = opts or {}
    local ok, result, request_err = pcall(client.request, client, DEBUG_SESSION_CMD, params)

    if not ok then
        return nil, ('debug session request failed: %s'):format(tostring(result))
    end

    if result == nil then
        return nil, request_err or 'phlow returned no session info'
    end

    if type(result) ~= 'table' then
        return nil, 'phlow returned a malformed session (expected a table)'
    end

    return result, nil
end

---@param fn fun(event: table)
---@return boolean, string?
---Subscribe to Phlow's debug event stream. The handler receives each decoded
---debug event table; handler errors are reported, never swallowed silently.
function M.on_debug_event(fn)
    if type(fn) ~= 'function' then
        return false, 'handler must be a function'
    end

    if client == nil then
        return false, 'not connected: call connect() first'
    end

    if type(client.on_event) ~= 'function' then
        return false, 'connected client does not support on_event'
    end

    local ok, subscribe_err = pcall(client.on_event, client, DEBUG_EVENT_NAME, fn)

    if not ok then
        return false, ('event subscription failed: %s'):format(tostring(subscribe_err))
    end

    return true, nil
end

---Close the Phlow connection exactly once and forget the client.
function M.disconnect()
    if client == nil then
        return
    end

    if type(client.close) == 'function' then
        pcall(client.close, client)
    end

    client = nil
    notify('disconnected')
end

return M
