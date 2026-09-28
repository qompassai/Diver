-- /qompassai/diver/lua/ai/harness/registry.lua
-- Qompass AI Agent Harness: explicit adapter/tool/workflow registry (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Explicit registration, never implicit discovery. Adapters, tools, and
-- workflows are named, validated, and listed in sorted order so behavior
-- is deterministic and auditable. Built-in protocol adapters translate
-- the existing acp/a2a/mcp/phlow/rose/herd modules; they are wrappers,
-- not rewrites.

local M = {}

local ENTRIES_MAX = 256
local NAME_PATTERN = '^[a-z][a-z0-9_]*$'

---@param name string
---@return boolean ok
---@return string? err
local function validate_name(name)
    if type(name) ~= 'string' or name == '' then
        return nil, 'name must be a non-empty string'
    end
    if not name:match(NAME_PATTERN) then
        return nil, 'name must match ' .. NAME_PATTERN
    end
    return true
end

---Create an empty registry.
---@return table
function M.new()
    return { adapters = {}, tools = {}, workflows = {} }
end

---@param registry table
---@param name string
---@param adapter table
---@return boolean ok
---@return string? err
function M.register_adapter(registry, name, adapter)
    assert(registry ~= nil, 'registry required')
    local valid, err = validate_name(name)
    if not valid then
        return nil, err
    end
    if type(adapter) ~= 'table' then
        return nil, 'adapter must be a table'
    end
    for _, field in ipairs({ 'probe', 'start', 'cancel', 'close' }) do
        if type(adapter[field]) ~= 'function' then
            return nil, 'adapter.' .. field .. ' must be a function'
        end
    end
    if registry.adapters[name] ~= nil then
        return nil, 'adapter already registered: ' .. name
    end
    local count = 0
    for _ in pairs(registry.adapters) do
        count = count + 1
    end
    if count >= ENTRIES_MAX then
        return nil, 'adapter registry is full'
    end
    registry.adapters[name] = adapter
    return true
end

---@param registry table
---@param name string
---@return table?
function M.get_adapter(registry, name)
    assert(registry ~= nil, 'registry required')
    return registry.adapters[name]
end

---Adapter names in sorted order for deterministic negotiation.
---@param registry table
---@return string[]
function M.list_adapters(registry)
    assert(registry ~= nil, 'registry required')
    local names = {}
    for name in pairs(registry.adapters) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---@param registry table
---@param name string
---@param def table
---@return boolean ok
---@return string? err
function M.register_tool(registry, name, def)
    assert(registry ~= nil, 'registry required')
    local valid, err = validate_name(name)
    if not valid then
        return nil, err
    end
    if type(def) ~= 'table' then
        return nil, 'tool definition must be a table'
    end
    if type(def.description) ~= 'string' or def.description == '' then
        return nil, 'tool.description must be a non-empty string'
    end
    if registry.tools[name] ~= nil then
        return nil, 'tool already registered: ' .. name
    end
    registry.tools[name] = def
    return true
end

---@param registry table
---@param name string
---@return table?
function M.get_tool(registry, name)
    assert(registry ~= nil, 'registry required')
    return registry.tools[name]
end

---Tool names in sorted order.
---@param registry table
---@return string[]
function M.list_tools(registry)
    assert(registry ~= nil, 'registry required')
    local names = {}
    for name in pairs(registry.tools) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---@param registry table
---@param name string
---@param def table
---@return boolean ok
---@return string? err
function M.register_workflow(registry, name, def)
    assert(registry ~= nil, 'registry required')
    local valid, err = validate_name(name)
    if not valid then
        return nil, err
    end
    if type(def) ~= 'table' then
        return nil, 'workflow definition must be a table'
    end
    if type(def.adapter) ~= 'string' or def.adapter == '' then
        return nil, 'workflow.adapter must be a non-empty string'
    end
    if registry.workflows[name] ~= nil then
        return nil, 'workflow already registered: ' .. name
    end
    registry.workflows[name] = def
    return true
end

---@param registry table
---@param name string
---@return table?
function M.get_workflow(registry, name)
    assert(registry ~= nil, 'registry required')
    return registry.workflows[name]
end

---Register the six built-in protocol adapters. Each is a thin translator
---over its existing module; nothing in ai/acp, ai/a2a, ai/mcp, ai/phlow,
---ai/rose, or ai/herd is modified.
---@param registry table
---@return boolean ok
---@return string? err
function M.register_builtins(registry)
    assert(registry ~= nil, 'registry required')
    local names = { 'acp', 'a2a', 'mcp', 'phlow', 'rose', 'herd' }
    for _, name in ipairs(names) do
        local found, adapter = pcall(require, 'ai.harness.adapters.' .. name)
        if not found then
            return nil, 'builtin adapter failed to load: ' .. name .. ': ' .. tostring(adapter)
        end
        local ok, err = M.register_adapter(registry, name, adapter)
        if not ok then
            return nil, err
        end
    end
    return true
end

return M
