-- #################################################################
-- lua/dap/lifecycle.lua
-- Qompass AI Diver DAP Session Lifecycle Tracker
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

--- Explicit DAP lifecycle state machine (presentation side only).
---
--- Plain-language version: a debug session follows a strict script --
--- say hello (initialize), remember what the adapter can do, start the
--- program (launch/attach), wait for the adapter's "ready" signal, set
--- breakpoints, then confirm setup is done. This module tracks where a
--- session is in that script. Wrong order is reported as an error value,
--- never a crash. It owns no orchestration state and spawns nothing; it
--- just records transitions so the UI layer cannot send requests early.
---@module 'dap.lifecycle'

local M = {}

---@alias dap.LifecycleState 'idle'|'negotiating'|'launched'|'configuring'|'running'
---|'terminated'|'exited'|'disconnected'|'failed'

---@class dap.Lifecycle
---@field private _state dap.LifecycleState
---@field private _caps table<string, any>|nil capabilities recorded from initialize
---@field private _failure string|nil adapter-process failure reason
local Lifecycle = {}
local Lifecycle_mt = { __index = Lifecycle }

--- States where the session is live and an end event may still arrive.
---@type table<dap.LifecycleState, boolean>
local LIVE = {
    negotiating = true,
    launched = true,
    configuring = true,
    running = true,
}
--- States where the session is over; further transitions are rejected.
---@type table<dap.LifecycleState, boolean>
local TERMINAL = {
    terminated = true,
    exited = true,
    disconnected = true,
    failed = true,
}

---@param tracker dap.Lifecycle
---@param want string expected current state
---@return nil, string
local function invalid(tracker, want)
    return nil, string.format('invalid DAP transition: state=%s, expected %s', tracker._state, want)
end

--- Create a fresh lifecycle tracker in 'idle'.
---@return dap.Lifecycle
function M.new()
    return setmetatable({ _state = 'idle', _caps = nil, _failure = nil }, Lifecycle_mt)
end

--- Current lifecycle state.
---@return dap.LifecycleState
function Lifecycle:state()
    return self._state
end

--- Capabilities recorded from the initialize response, nil before that.
---@return table<string, any>?
function Lifecycle:capabilities()
    return self._caps
end

--- Adapter-process failure reason, nil when the process has not failed.
---@return string?
function Lifecycle:failure_reason()
    return self._failure
end

--- Record the initialize response capabilities. idle -> negotiating.
---@param caps table<string, any>
---@return boolean ok, string? err
function Lifecycle:on_initialize(caps)
    if self._state ~= 'idle' then
        return invalid(self, 'idle')
    end
    if type(caps) ~= 'table' then
        return nil, 'on_initialize: capabilities must be a table'
    end
    self._caps = caps
    self._state = 'negotiating'
    return true
end

--- launch or attach was sent after capabilities were recorded.
---@return boolean ok, string? err
function Lifecycle:on_launch()
    if self._state ~= 'negotiating' then
        return invalid(self, 'negotiating')
    end
    self._state = 'launched'
    return true
end

--- The adapter's `initialized` event arrived; breakpoints may be configured.
---@return boolean ok, string? err
function Lifecycle:on_initialized_event()
    if self._state ~= 'launched' then
        return invalid(self, 'launched')
    end
    self._state = 'configuring'
    return true
end

--- True only while breakpoints/exception filters are being configured,
--- i.e. only after initialize negotiated capabilities successfully.
---@return boolean
function Lifecycle:configuration_done_allowed()
    return self._state == 'configuring'
end

--- configurationDone was sent after negotiation; normal requests may flow.
---@return boolean ok, string? err
function Lifecycle:on_configuration_done()
    if self._state ~= 'configuring' then
        return invalid(self, 'configuring')
    end
    self._state = 'running'
    return true
end

---@param tracker dap.Lifecycle
---@param to dap.LifecycleState
---@return boolean ok, string? err
local function finish(tracker, to)
    if TERMINAL[tracker._state] then
        return nil, 'session already ended: ' .. tracker._state
    end
    if not LIVE[tracker._state] then
        return nil, 'cannot end session from state ' .. tracker._state
    end
    tracker._state = to
    return true
end

--- Adapter sent `terminated`. Allowed from any live state, independently.
---@return boolean ok, string? err
function Lifecycle:on_terminated()
    return finish(self, 'terminated')
end

--- Adapter sent `exited`. Allowed from any live state, independently.
---@return boolean ok, string? err
function Lifecycle:on_exited()
    return finish(self, 'exited')
end

--- Adapter sent `disconnect` (or the transport closed). Independent of others.
---@return boolean ok, string? err
function Lifecycle:on_disconnect()
    return finish(self, 'disconnected')
end

--- The adapter process itself failed (spawn error, crash, bad exit).
---@param reason string|nil
---@return boolean ok, string? err
function Lifecycle:on_adapter_failure(reason)
    local ok, err = finish(self, 'failed')
    if not ok then
        return nil, err
    end
    self._failure = type(reason) == 'string' and reason ~= '' and reason or 'adapter process failed'
    return true
end

return M
