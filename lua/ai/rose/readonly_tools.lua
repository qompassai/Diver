-- /qompassai/Diver/lua/ai/rose/readonly_tools.lua
-- Read-only view of the native Rose tool set: every tool except file_write.
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The plan/generate entry points (ai.rose.plan, ai.rose.generate) inject
-- this module into agent.run so the model can inspect the workspace but
-- can never write files before the user confirms them in the builder.
-- Shape matches ai.rose.tools: call(name, args) and schemas().

local M = {}

local WRITE_TOOLS = { file_write = true }

---@return table base The full native tool module; raises when unavailable.
local function base_tools()
    return require('ai.rose.tools')
end

-- Export every schema except the write tools. The agent requires
-- editor_context/editor_check to stay present for validation.
---@return table[] schemas
function M.schemas()
    local result = {}
    for _, schema in ipairs(base_tools().schemas()) do
        local fn = type(schema) == 'table' and schema['function']
        local name = type(fn) == 'table' and fn.name
        if not WRITE_TOOLS[name] then
            result[#result + 1] = schema
        end
    end
    return result
end

-- Call a tool by name; write tools are refused, everything else
-- delegates to the native implementation (which never raises).
---@param name string
---@param args table?
---@return table result
function M.call(name, args)
    if WRITE_TOOLS[name] then
        return {
            status = 'error',
            error = 'file_write is disabled for plan/generate; return file contents in the response text',
        }
    end
    return base_tools().call(name, args)
end

return M
