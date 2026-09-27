-- #################################################################
-- /qompassai/Diver/lua/games/love2d/adapters/init.lua
-- Qompass AI LÖVE2D Engine Adapter Contract
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
-- The adapter contract for engine-specific LÖVE2D integrations. There are
-- no per-engine files in this directory: an adapter is any Lua module that
-- satisfies the Love2dEngineAdapter shape below. validate_adapter/1 is the
-- gate -- init.lua refuses to register adapters that fail it.
--
-- Honesty rule: asset_interchange must name at least one limitation, and
-- Unity/Unreal-style thin integrations must declare runtime_interop=false.
-- Asset interchange (converting/importing assets) is not runtime
-- interoperability (running foreign engine code), and the contract forces
-- adapters to say so explicitly.
local libs = require('games.love2d.libs')

local M = {}

---@class Love2dAssetInterchange
---@field capabilities string[] what the adapter can move between engines
---@field limits string[] what it cannot do (must name at least one)
---@field runtime_interop boolean true only when foreign engine code runs

---@class Love2dEngineAdapter
---@field engine_key string unique key, e.g. 'custom' ([%w_%-]+)
---@field label string human-readable name
---@field love_version_requirement string e.g. '11.5' or '>=11.0'
---@field libraries string[] love2d library catalog keys the adapter needs
---@field run_args? string[] extra arguments passed to the love binary
---@field asset_interchange Love2dAssetInterchange

-- Adapter labels that imply a foreign engine thin integration. These may
-- only describe asset interchange, never runtime interop.
local THIN_INTEGRATION_HINTS = { 'unity', 'unreal', 'godot' }

---@param value any
---@return boolean
local function is_nonempty_string(value)
    return type(value) == 'string' and value ~= ''
end

---@param value any
---@return boolean
local function is_string_list(value)
    if type(value) ~= 'table' then
        return false
    end
    for _, item in ipairs(value) do
        if not is_nonempty_string(item) then
            return false
        end
    end
    return true
end

---@param mod table adapter module under test
---@return boolean ok
---@return string[] errors (empty when ok)
function M.validate_adapter(mod)
    local errors = {}
    local function fail(msg)
        errors[#errors + 1] = msg
    end
    if type(mod) ~= 'table' then
        return false, { 'adapter must be a table' }
    end
    if not is_nonempty_string(mod.engine_key) or not mod.engine_key:match('^[%w_%-]+$') then
        fail('engine_key must be a non-empty [%w_%-]+ string')
    end
    if not is_nonempty_string(mod.label) then
        fail('label must be a non-empty string')
    end
    if not is_nonempty_string(mod.love_version_requirement) then
        fail('love_version_requirement must be a non-empty string')
    end
    if type(mod.libraries) ~= 'table' then
        fail('libraries must be a table of catalog keys')
    else
        for _, key in ipairs(mod.libraries) do
            if not is_nonempty_string(key) then
                fail('libraries entries must be non-empty strings')
            elseif libs.get(key) == nil then
                fail('unknown library in libraries: ' .. key)
            end
        end
    end
    if mod.run_args ~= nil and not is_string_list(mod.run_args) then
        fail('run_args must be a list of strings when present')
    end
    local interchange = mod.asset_interchange
    if type(interchange) ~= 'table' then
        fail('asset_interchange must be a table')
    else
        if not is_string_list(interchange.capabilities) or #interchange.capabilities == 0 then
            fail('asset_interchange.capabilities must be a non-empty string list')
        end
        if not is_string_list(interchange.limits) or #interchange.limits == 0 then
            fail('asset_interchange.limits must name at least one limitation')
        end
        if type(interchange.runtime_interop) ~= 'boolean' then
            fail('asset_interchange.runtime_interop must be a boolean')
        end
        local label = type(mod.label) == 'string' and mod.label:lower() or ''
        local key = type(mod.engine_key) == 'string' and mod.engine_key:lower() or ''
        for _, hint in ipairs(THIN_INTEGRATION_HINTS) do
            if label:find(hint, 1, true) ~= nil or key:find(hint, 1, true) ~= nil then
                if interchange.runtime_interop ~= false then
                    fail(hint .. ' thin integration must declare runtime_interop=false (asset interchange only)')
                end
                break
            end
        end
    end
    return #errors == 0, errors
end

return M
