-- /qompassai/Diver/lua/ai/mcp/declared.lua
-- Qompass AI Declared MCP Server Loader (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
--
-- Loads lua/ai/mcp/declared_servers.lua, validates each declaration through
-- registry.validate() (executable presence is not required at load: a
-- missing binary fails loudly at spawn, not silently at startup), and
-- returns the active entries. A corrupt declaration file or a bad entry is
-- reported via the problems list and skipped; one bad entry never drops the
-- rest. Returned entries carry declared = true (in-memory only).

local registry = require('ai.mcp.registry')
local secrets = require('ai.mcp.secrets')

local M = {}

---@class McpDeclaredProblem
---@field index integer position in declared_servers.lua (0 = file-level)
---@field err string

---@return McpServerEntry[] active enabled and valid, each with declared = true
---@return McpDeclaredProblem[] problems
function M.load()
    local ok, declarations = pcall(require, 'ai.mcp.declared_servers')
    if not ok then
        local msg = tostring(declarations):sub(1, 120)
        return {}, { { index = 0, err = 'cannot load declared_servers: ' .. msg } }
    end
    if type(declarations) ~= 'table' then
        return {}, { { index = 0, err = 'declared_servers must return a table' } }
    end
    local active = {}
    local problems = {}
    local seen = {}
    for index, entry in ipairs(declarations) do
        local valid, err = registry.validate(entry, { require_executable = false })
        if not valid then
            problems[#problems + 1] = { index = index, err = err }
        else
            local sok, serr = secrets.validate_refs(entry.secrets)
            if not sok then
                problems[#problems + 1] = { index = index, err = serr }
            elseif seen[entry.name] then
                problems[#problems + 1] = { index = index, err = 'duplicate declared name: ' .. entry.name }
            elseif entry.enabled then
                seen[entry.name] = true
                local copy = vim.deepcopy(entry)
                copy.declared = true
                active[#active + 1] = copy
            end
        end
    end
    return active, problems
end

return M
