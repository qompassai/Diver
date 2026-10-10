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
-- Harness-native builtin tools, in registration order. Each name is a
-- module ai.harness.tools.<name> returning one tool def table. Empty by
-- design: tools join the harness by producer registration (see
-- ai.harness.register_tool); this list covers only tools the harness
-- itself owns, and it owns none yet.
local BUILTIN_TOOLS = {}

---@param name string
---@return boolean|nil ok
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
---@return boolean|nil ok
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

---Register a tool. A tool def must be runnable at registration time:
---description (non-empty string), run (function), and input_schema
---(table mapping field names to { type = ..., required = ... }) are all
---required, so a registered-but-unrunnable tool can never exist. An
---optional risk field names the policy risk class dispatch decides
---under; dispatch defaults it to 'process' when absent.
---@param registry table
---@param name string
---@param def table
---@return boolean|nil ok
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
    if type(def.run) ~= 'function' then
        return nil, 'tool.run must be a function'
    end
    if type(def.input_schema) ~= 'table' then
        return nil, 'tool.input_schema must be a table'
    end
    if registry.tools[name] ~= nil then
        return nil, 'tool already registered: ' .. name
    end
    local count = 0
    for _ in pairs(registry.tools) do
        count = count + 1
    end
    if count >= ENTRIES_MAX then
        return nil, 'tool registry is full'
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
---@return boolean|nil ok
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
    local count = 0
    for _ in pairs(registry.workflows) do
        count = count + 1
    end
    if count >= ENTRIES_MAX then
        return nil, 'workflow registry is full'
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

---Workflow names in sorted order.
---@param registry table
---@return string[]
function M.list_workflows(registry)
    assert(registry ~= nil, 'registry required')
    local names = {}
    for name in pairs(registry.workflows) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

---Register the six built-in protocol adapters. Each is a thin translator
---over its existing module; nothing in ai/acp, ai/a2a, ai/mcp, ai/phlow,
---ai/rose, or ai/herd is modified.
---@param registry table
---@return boolean|nil ok
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

---Register the harness-native builtin tools. Each name loads the module
---ai.harness.tools.<name>, which returns one tool def table validated by
---register_tool, so a builtin that cannot run fails registration and
---with it harness setup (fail-closed, mirroring register_builtins). The
---optional names argument overrides the builtin list; production
---callers omit it and get BUILTIN_TOOLS.
---@param registry table
---@param names? string[]
---@return boolean|nil ok
---@return string? err
function M.register_builtin_tools(registry, names)
    assert(registry ~= nil, 'registry required')
    names = names or BUILTIN_TOOLS
    for _, name in ipairs(names) do
        local found, def = pcall(require, 'ai.harness.tools.' .. name)
        if not found then
            return nil, 'builtin tool failed to load: ' .. name .. ': ' .. tostring(def)
        end
        local ok, err = M.register_tool(registry, name, def)
        if not ok then
            return nil, err
        end
    end
    return true
end

return M
