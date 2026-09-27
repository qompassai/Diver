-- #################################################################
-- lua/dap/registry/init.lua
-- Qompass AI Diver DAP Adapter Registry
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

--- Declarative DAP adapter registry with readiness tracking.
---
--- Plain-language version: this module is a phone book for debug adapters.
--- Each adapter gets a small declaration card (what program to run, which
--- file types it handles, how to check its version). The registry also tracks
--- how ready each adapter is: Known (we have its card) -> Discovered (its
--- program was found) -> Compatible (its version is new enough) ->
--- Negotiated (it answered our hello message) -> Validated (a test debug
--- session actually worked). An adapter may only move one step forward at a
--- time, so a merely-Discovered adapter can never be presented as working.
---@module 'dap.registry'

local M = {}

--- Maximum descriptors held; the set is small and curated, this is a guard.
local MAX_DESCRIPTORS = 64

---@alias dap.ReadinessState 'known'|'discovered'|'compatible'|'negotiated'|'validated'

---@type dap.ReadinessState[]
local STATE_ORDER = { 'known', 'discovered', 'compatible', 'negotiated', 'validated' }

---@param state dap.ReadinessState
---@return integer position in STATE_ORDER, 0 when unknown
local function state_index(state)
    for i, name in ipairs(STATE_ORDER) do
        if name == state then
            return i
        end
    end
    return 0
end

---@class dap.RegistryDescriptor
---@field id string Adapter id, e.g. 'moonwalk'
---@field executable? string|{ command?: string, names?: string[], args?: string[] }
---@field filetypes? string[]
---@field transports? string[]
---@field discovery? fun(): string|nil Resolves the executable path, nil when absent
---@field version_probe? fun(exe: string): (string|nil), (string|nil)
---@field version_policy? { minimum?: string, scheme?: string }
---@field capability_expectations? table<string, any>
---@field security? table<string, any>
---@field launch? fun(opts: table): (table|nil) launch params or nil,err
---@field attach? fun(opts: table): (table|nil) attach params or nil,err
---@field remote? table<string, any>
---@field source_mapping? table<string, any>
---@field health_checks? table<string, fun(exe: string): boolean>

---@type table<string, dap.RegistryDescriptor>
local descriptors = {}
---@type table<string, dap.ReadinessState>
local states = {}
local descriptor_count = 0

---@param descriptor any
---@return boolean, string?
local function valid_descriptor(descriptor)
    if type(descriptor) ~= 'table' then
        return false, 'descriptor must be a table'
    end
    if type(descriptor.id) ~= 'string' or descriptor.id == '' then
        return false, 'descriptor.id must be a non-empty string'
    end
    if descriptor.filetypes ~= nil and type(descriptor.filetypes) ~= 'table' then
        return false, 'descriptor.filetypes must be a list of strings'
    end
    local has_discovery = type(descriptor.discovery) == 'function'
    local has_executable = type(descriptor.executable) == 'string' or type(descriptor.executable) == 'table'
    if not has_discovery and not has_executable then
        return false, 'descriptor needs discovery() or executable'
    end
    return true
end

--- Register (or re-register) an adapter descriptor. Starts at 'known'.
---@param descriptor dap.RegistryDescriptor
---@return boolean ok, string? err
function M.register(descriptor)
    local ok, err = valid_descriptor(descriptor)
    if not ok then
        return false, err
    end
    if descriptors[descriptor.id] == nil then
        if descriptor_count >= MAX_DESCRIPTORS then
            return false, 'adapter registry is full'
        end
        descriptor_count = descriptor_count + 1
    end
    descriptors[descriptor.id] = descriptor
    states[descriptor.id] = 'known'
    return true
end

--- Fetch a registered descriptor, or nil for an unknown id.
---@param id string
---@return dap.RegistryDescriptor?
function M.get(id)
    return descriptors[id]
end

--- Current readiness state for an adapter id, or nil when unknown.
---@param id string
---@return dap.ReadinessState?
function M.state(id)
    return states[id]
end

--- Move an adapter exactly one readiness step forward. Skipping steps,
--- moving backwards, or targeting an unknown id/state fails.
---@param id string
---@param to dap.ReadinessState
---@return boolean ok, string? err
function M.advance(id, to)
    local from = states[id]
    if from == nil then
        return false, 'unknown adapter id: ' .. tostring(id)
    end
    local from_i = state_index(from)
    local to_i = state_index(to)
    if to_i == 0 then
        return false, 'unknown readiness state: ' .. tostring(to)
    end
    if to_i ~= from_i + 1 then
        return false, string.format('refusing readiness jump %s -> %s for %s', from, tostring(to), id)
    end
    states[id] = to
    return true
end

---@class dap.RegistryEntry
---@field id string
---@field state dap.ReadinessState

--- Sorted snapshot of registered adapters and their readiness states.
---@return dap.RegistryEntry[]
function M.list()
    local entries = {}
    for id, state in pairs(states) do
        entries[#entries + 1] = { id = id, state = state }
    end
    table.sort(entries, function(a, b)
        return a.id < b.id
    end)
    return entries
end

return M
