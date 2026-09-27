-- #################################################################
-- lua/dap/registry/discovery.lua
-- Qompass AI Diver DAP Adapter Discovery and Probing
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

--- Executable discovery, version probing, and health checks for adapters.
---
--- Plain-language version: this module answers three questions about each
--- registered debug adapter, in order: is its program installed
--- (Known -> Discovered), is it new enough (Discovered -> Compatible), and
--- does it look healthy. Every probe is bounded: only a few candidate names
--- are tried, and subprocess calls die after a short timeout.
---@module 'dap.registry.discovery'

local registry = require('dap.registry')

local M = {}

--- Hard bound on subprocess probes, in milliseconds.
local PROBE_TIMEOUT_MS = 3000
--- Hard bound on candidate executable names tried per adapter.
local MAX_CANDIDATES = 8

--- Resolve the executable path for a descriptor without spawning anything.
---@param descriptor dap.RegistryDescriptor
---@return string|nil path when found
local function resolve_executable(descriptor)
    if type(descriptor.discovery) == 'function' then
        local ok, result = pcall(descriptor.discovery)
        if ok and type(result) == 'string' and result ~= '' then
            return result
        end
        return nil
    end
    local exe = descriptor.executable
    local names = {}
    if type(exe) == 'string' then
        names = { exe }
    elseif type(exe) == 'table' then
        if type(exe.command) == 'string' then
            names = { exe.command }
        elseif type(exe.names) == 'table' then
            names = exe.names
        end
    end
    local limit = math.min(#names, MAX_CANDIDATES)
    for i = 1, limit do
        local name = names[i]
        if type(name) == 'string' and name ~= '' then
            local found = vim.fn.exepath(name)
            if found ~= '' then
                return found
            end
        end
    end
    return nil
end

---@class dap.DiscoveryResult
---@field state dap.ReadinessState
---@field path string|nil

--- Check every registered adapter's executable (PATH-based, no spawning).
--- Promotes Known -> Discovered; never touches higher states.
---@return table<string, dap.DiscoveryResult> keyed by adapter id
function M.discover()
    local results = {}
    for _, entry in ipairs(registry.list()) do
        local descriptor = registry.get(entry.id)
        local path = descriptor and resolve_executable(descriptor) or nil
        if path and registry.state(entry.id) == 'known' then
            registry.advance(entry.id, 'discovered')
        end
        results[entry.id] = { state = registry.state(entry.id), path = path }
    end
    return results
end

--- Compare dotted version strings. Returns -1, 0, 1 like a comparator.
---@param a string
---@param b string
---@return integer
local function compare_versions(a, b)
    local function parts(version)
        local nums = {}
        for piece in tostring(version):gmatch('[^.]+') do
            local n = tonumber(piece:match('^%d+'))
            if #nums >= 4 then
                break
            end
            nums[#nums + 1] = n or 0
        end
        return nums
    end
    local pa, pb = parts(a), parts(b)
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

--- Run a descriptor's version_probe against its resolved executable.
--- On success (probe ran and policy satisfied) promotes to 'compatible'.
---@param id string adapter id
---@return boolean ok, string|nil version_or_err
function M.probe_version(id)
    local descriptor = registry.get(id)
    if descriptor == nil then
        return false, 'unknown adapter id: ' .. tostring(id)
    end
    if registry.state(id) ~= 'discovered' then
        return false, 'adapter must be discovered before version probing, state=' .. tostring(registry.state(id))
    end
    if type(descriptor.version_probe) ~= 'function' then
        return false, 'adapter ' .. id .. ' has no version_probe'
    end
    local path = resolve_executable(descriptor)
    if path == nil then
        return false, 'executable no longer resolvable for ' .. id
    end
    local ok, version = pcall(descriptor.version_probe, path)
    if not ok or type(version) ~= 'string' or version == '' then
        return false, 'version probe failed for ' .. id .. ': ' .. tostring(version)
    end
    local policy = descriptor.version_policy
    if type(policy) == 'table' and type(policy.minimum) == 'string' and policy.minimum ~= '' then
        if compare_versions(version, policy.minimum) < 0 then
            return false, string.format('adapter %s version %s below minimum %s', id, version, policy.minimum)
        end
    end
    local advanced, adv_err = registry.advance(id, 'compatible')
    if not advanced then
        return false, adv_err
    end
    return true, version
end

---@class dap.HealthResult
---@field ok boolean
---@field checks table<string, boolean> per-check pass/fail

--- Run a descriptor's health_checks against its resolved executable.
--- Pre-launch only: this does not promote readiness; a real launch/attach
--- smoke promotes to 'validated' via registry.advance(id, 'validated').
---@param id string adapter id
---@return boolean ok, dap.HealthResult|string details_or_err
function M.run_health_checks(id)
    local descriptor = registry.get(id)
    if descriptor == nil then
        return false, 'unknown adapter id: ' .. tostring(id)
    end
    if type(descriptor.health_checks) ~= 'table' then
        return false, 'adapter ' .. id .. ' has no health_checks'
    end
    local path = resolve_executable(descriptor)
    if path == nil then
        return false, 'executable not resolvable for ' .. id
    end
    local checks = {}
    local all_ok = true
    for name, check in pairs(descriptor.health_checks) do
        local check_ok = false
        if type(check) == 'function' then
            local ok, result = pcall(check, path)
            check_ok = ok and result == true
        end
        checks[name] = check_ok
        all_ok = all_ok and check_ok
    end
    return all_ok, { ok = all_ok, checks = checks }
end

--- Probe timeout shared by descriptors that shell out.
---@return integer milliseconds
function M.probe_timeout_ms()
    return PROBE_TIMEOUT_MS
end

return M
