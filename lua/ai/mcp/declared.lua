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
--
-- Language declarations merge in here too: the config.lang modules listed
-- in LANG_MCP_MODULES may carry an M.mcp_servers table (same entry shape,
-- authored enabled = false). Collection happens inside load() -- never at
-- this module's load time -- because config.lang loads lazily per FileType
-- and may not be loaded when the MCP layer first runs; load() is already
-- called lazily by the registry, so every require edge stays
-- one-directional (ai.mcp -> config.lang, never the reverse). Merge rules:
-- declared_servers.lua is processed first and the first valid declaration
-- of a name wins, so a lang entry can never override or shadow a
-- hand-written one -- a collision is reported as a problem instead. A lang
-- module that fails to load is skipped silently (the lang loader reports
-- its own failures); a declaration that IS collected but invalid is a
-- problem, in the same style as a bad declared_servers.lua entry. Lang
-- entries name their command as found on PATH; the collected copy carries
-- the absolute path resolved via exepath (an unresolvable command is a
-- problem). Source tables are never mutated.
--
-- Returns: active (enabled and valid), problems, all (every valid
-- declaration, enabled or not -- the full declared set).

local registry = require('ai.mcp.registry')
local secrets = require('ai.mcp.secrets')

local M = {}

---config.lang modules that may declare M.mcp_servers (alphabetical). A
---lang module that grows an mcp_servers table must be listed here.
local LANG_MCP_MODULES = { 'elixir', 'go', 'nix', 'sf' }

---@class McpDeclaredProblem
---@field index integer position in declared_servers.lua (0 = file-level
---or a config.lang declaration; err names the source)
---@field err string

---@param modname string config.lang module name
---@param entry any one M.mcp_servers entry from that module
---@param problems McpDeclaredProblem[]
---@return McpServerEntry? copy validated copy with declared = true
local function lang_entry(modname, entry, problems)
    local source = 'config.lang.' .. modname
    if type(entry) ~= 'table' then
        problems[#problems + 1] = { index = 0, err = source .. ': mcp_servers entry must be a table' }
        return nil
    end
    local copy = vim.deepcopy(entry)
    if type(copy.command) == 'string' and copy.command:sub(1, 1) ~= '/' then
        if type(vim.fn.exepath) ~= 'function' then
            -- No resolver in this environment (bare test stubs): the entry
            -- cannot be collected here; that is not a data problem.
            return nil
        end
        local ok, resolved = pcall(vim.fn.exepath, copy.command)
        if not ok or resolved == '' then
            problems[#problems + 1] = {
                index = 0,
                err = source .. ': cannot resolve command on PATH: ' .. copy.command,
            }
            return nil
        end
        copy.command = resolved
    end
    local valid, err = registry.validate(copy, { require_executable = false })
    if not valid then
        problems[#problems + 1] = { index = 0, err = source .. ': ' .. err }
        return nil
    end
    local sok, serr = secrets.validate_refs(copy.secrets)
    if not sok then
        problems[#problems + 1] = { index = 0, err = source .. ': ' .. serr }
        return nil
    end
    copy.declared = true
    return copy
end

---@return McpServerEntry[] active enabled and valid, each with declared = true
---@return McpDeclaredProblem[] problems
---@return McpServerEntry[] all every valid declaration, each with declared = true
function M.load()
    local ok, declarations = pcall(require, 'ai.mcp.declared_servers')
    if not ok then
        local msg = tostring(declarations):sub(1, 120)
        return {}, { { index = 0, err = 'cannot load declared_servers: ' .. msg } }, {}
    end
    if type(declarations) ~= 'table' then
        return {}, { { index = 0, err = 'declared_servers must return a table' } }, {}
    end
    local active = {}
    local all = {}
    local problems = {}
    local seen = {}
    local claimed = {}
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
            else
                if not claimed[entry.name] then
                    claimed[entry.name] = true
                    local declared_copy = vim.deepcopy(entry)
                    declared_copy.declared = true
                    all[#all + 1] = declared_copy
                end
                if entry.enabled then
                    seen[entry.name] = true
                    local copy = vim.deepcopy(entry)
                    copy.declared = true
                    active[#active + 1] = copy
                end
            end
        end
    end
    for _, modname in ipairs(LANG_MCP_MODULES) do
        local lok, lang = pcall(require, 'config.lang.' .. modname)
        if lok and type(lang) == 'table' and type(lang.mcp_servers) == 'table' then
            for _, entry in ipairs(lang.mcp_servers) do
                local copy = lang_entry(modname, entry, problems)
                if copy ~= nil then
                    if claimed[copy.name] then
                        problems[#problems + 1] = {
                            index = 0,
                            err = 'config.lang.'
                                .. modname
                                .. ': duplicate declared name: '
                                .. copy.name
                                .. ' (earlier declaration wins)',
                        }
                    else
                        claimed[copy.name] = true
                        all[#all + 1] = copy
                        if copy.enabled then
                            active[#active + 1] = vim.deepcopy(copy)
                        end
                    end
                end
            end
        end
    end
    return active, problems, all
end

return M
