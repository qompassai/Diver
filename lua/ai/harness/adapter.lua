-- /qompassai/diver/lua/ai/harness/adapter.lua
-- Qompass AI Agent Harness: adapter contract and negotiation (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Adapters are capability-driven, never identified by protocol name in
-- harness logic. Capability negotiation decides whether a workflow may
-- pause for input, resume after restart, stream artifacts, or request
-- permissions. Each adapter preserves its protocol's native semantics:
-- ACP keeps session/turn separation, A2A keeps task lifecycles, MCP keeps
-- one client per server boundary, Phlow keeps durable external state,
-- Rose keeps provider-native fields, Herd keeps worker identity.

local types = require('ai.harness.types')

local M = {}

---@class AiHarnessCapabilities
---@field available boolean native module loadable and usable
---@field streaming boolean
---@field cancellation boolean
---@field resume boolean
---@field permissions boolean
---@field artifacts boolean
---@field remote boolean
---@field tools boolean
---@field max_input_bytes? integer
---@field wired_start boolean start() delegates to a verified native call

---@class AiHarnessAdapter
---@field name string
---@field probe fun(): AiHarnessCapabilities
---@field start fun(run: table, sink: AiHarnessSink): table?, string?
---@field send_input? fun(handle: table, input: table): boolean?, string?
---@field cancel fun(handle: table, reason: string): boolean?
---@field close fun(handle: table)

---Validate that a table honors the adapter contract.
---@param adapter table
---@return boolean ok
---@return string? err
function M.validate(adapter)
    if type(adapter) ~= 'table' then
        return nil, 'adapter must be a table'
    end
    if type(adapter.name) ~= 'string' or adapter.name == '' then
        return nil, 'adapter.name must be a non-empty string'
    end
    for _, field in ipairs({ 'probe', 'start', 'cancel', 'close' }) do
        if type(adapter[field]) ~= 'function' then
            return nil, 'adapter.' .. field .. ' must be a function'
        end
    end
    if adapter.send_input ~= nil and type(adapter.send_input) ~= 'function' then
        return nil, 'adapter.send_input must be a function when present'
    end
    return true
end

---Probe an adapter's capabilities without side effects. Probe failures
---become unavailable capabilities, never exceptions.
---@param adapter table
---@return AiHarnessCapabilities? caps
---@return string? err
function M.probe(adapter)
    local valid, err = M.validate(adapter)
    if not valid then
        return nil, err
    end
    local ok, caps = pcall(adapter.probe)
    if not ok then
        return nil, 'adapter probe raised: ' .. tostring(caps)
    end
    if type(caps) ~= 'table' then
        return nil, 'adapter probe must return a table'
    end
    for _, key in ipairs(types.CAPABILITY_KEYS) do
        if type(caps[key]) ~= 'boolean' then
            return nil, 'capability ' .. key .. ' must be a boolean'
        end
    end
    return caps
end

---Choose the first adapter (in sorted name order) whose probed
---capabilities satisfy every requested need. Needs use the same keys as
---capabilities; a need of true requires the capability.
---@param adapters table<string, table> name -> adapter
---@param needs table<string, boolean>?
---@return table? adapter
---@return string? err
function M.negotiate(adapters, needs)
    if type(adapters) ~= 'table' then
        return nil, 'adapters must be a table'
    end
    needs = needs or {}
    local names = {}
    for name in pairs(adapters) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local caps, err = M.probe(adapters[name])
        if caps ~= nil then
            local satisfied = true
            for _, key in ipairs(types.CAPABILITY_KEYS) do
                if needs[key] == true and caps[key] ~= true then
                    satisfied = false
                    break
                end
            end
            if satisfied then
                return adapters[name]
            end
        else
            _ = err
        end
    end
    return nil, 'no adapter satisfies the requested capabilities'
end

return M
