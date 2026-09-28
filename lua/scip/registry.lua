-- #################################################################
-- /qompassai/lua/scip/registry.lua
-- Qompass AI Diver SCIP Registry
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################

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
local api = vim.api
local config = require('scip.config')
local context = require('scip.context')
local root = require('scip.root')
local utils = require('scip.utils')
local M = {}
---@class ScipMatch
---@field command string
---@field context ScipContext
---@field indexer ScipIndexer
---@field name string

---@class ScipProbe
---@field command string? Resolved indexer command; present when resolution
---succeeded, even when not ready.
---@field ready boolean True when a project root resolved and the command is executable.
---@field err string? Failure description; set when the command could not be
---resolved or no project root was found. A resolved but non-executable
---command reports ready=false with command present and err unset.

---Probe failure reason when no project root resolves for an indexer.
---Health checks compare against this instead of probing against a cwd
---fallback.
M.NO_PROJECT_ROOT = 'no project root'

---Memoized executable probes, keyed by command.
---
---PATH scans are the expensive part of readiness checks, which run
---repeatedly (detect, health, coverage). Entries are valid only for the
---configuration generation they were computed under: whenever
---config.setup()/reset() replaces the config table, the cache is dropped.
---(registry.register mutates the live table in place, so its entries stay
---valid and newly registered commands are probed on demand.)
---@type table<string, boolean>
local executable_cache = {}

---Config table the executable cache was computed against.
---@type table?
local cached_config_values = nil

---Cached wrapper around utils.executable.
---@param command string
---@return boolean
local function cached_executable(command)
    local values = config.get()

    if values ~= cached_config_values then
        executable_cache = {}
        cached_config_values = values
    end

    local cached = executable_cache[command]

    if cached ~= nil then
        return cached
    end

    local ready = utils.executable(command)

    executable_cache[command] = ready

    return ready
end

---Shared resolve-root → build-context → resolve-command → probe-executable
---pipeline backing M.probe and M.detect.
---
---@param name string Indexer name.
---@param bufnr integer Buffer used for root and command resolution.
---@param project_root string? Pre-resolved project root; when nil, markers
---are searched with root.find (no cwd fallback).
---@return ScipMatch? match Full match when the indexer is ready.
---@return ScipProbe probe Readiness report.
local function pipeline(name, bufnr, project_root)
    local indexer = M.get(name)

    if indexer == nil then
        return nil, { ready = false, err = 'Unknown or disabled SCIP indexer: ' .. name }
    end

    if project_root == nil then
        project_root = root.find(bufnr, indexer.markers)
    end

    -- Best-effort root for command resolution only: static commands ignore it
    -- entirely, and dynamic commands (php's vendor/bin lookup) degrade to
    -- their global fallback. Readiness still requires a real project root.
    local resolve_root = project_root or vim.fs.normalize(vim.fn.getcwd())
    local ctx, ctx_error = context.new(name, bufnr, resolve_root)

    if ctx == nil then
        return nil, { ready = false, err = ctx_error or 'invalid buffer' }
    end

    local command, resolve_error = utils.resolve_command(indexer.command, ctx)

    if command == nil then
        return nil, {
            ready = false,
            err = resolve_error or ('Invalid command for indexer: ' .. name),
        }
    end

    if project_root == nil then
        return nil, { command = command, ready = false, err = M.NO_PROJECT_ROOT }
    end

    if not cached_executable(command) then
        return nil, { command = command, ready = false }
    end

    return {
        command = command,
        context = ctx,
        indexer = indexer,
        name = name,
    }, { command = command, ready = true }
end

---Return an enabled indexer by name.
---@param name string
---@return ScipIndexer?
function M.get(name)
    local indexer = config.get().indexers[name]

    if indexer == nil or indexer.enabled == false then
        return nil
    end

    return indexer
end

---Return enabled indexer names in configured priority order.
---@return string[]
function M.names()
    local names = {}

    for _, name in ipairs(config.get().indexer_order) do
        if M.get(name) ~= nil then
            names[#names + 1] = name
        end
    end

    return names
end

---Return sorted filetypes supported by an indexer.
---@param indexer ScipIndexer
---@return string[]
function M.filetypes(indexer)
    local filetypes = {}

    for filetype, enabled in pairs(indexer.filetypes) do
        if enabled then
            filetypes[#filetypes + 1] = filetype
        end
    end

    table.sort(filetypes)

    return filetypes
end

---Determine whether an indexer matches a buffer's filetype and project.
---@param indexer ScipIndexer
---@param bufnr integer
---@return string?
function M.matching_root(indexer, bufnr)
    local filetype = vim.bo[bufnr].filetype

    if indexer.filetypes[filetype] ~= true then
        return nil
    end

    return root.find(bufnr, indexer.markers)
end

---Resolve a named indexer for a buffer.
---@param name string
---@param bufnr integer
---@param root_override? string
---@return ScipMatch?, string?
function M.resolve(name, bufnr, root_override)
    local indexer = M.get(name)

    if indexer == nil then
        return nil, 'Unknown or disabled SCIP indexer: ' .. name
    end

    local project_root

    if root_override ~= nil and root_override ~= '' then
        project_root = vim.fs.normalize(root_override)
    else
        project_root = root.resolve(bufnr, indexer.markers)
    end

    local ctx, ctx_error = context.new(name, bufnr, project_root)

    if ctx == nil then
        return nil, ctx_error
    end

    local command, command_error = utils.resolve_command(indexer.command, ctx)

    if command == nil then
        return nil, command_error
    end

    if not cached_executable(command) then
        return nil, 'SCIP indexer is not executable: ' .. command
    end

    return {
        command = command,
        context = ctx,
        indexer = indexer,
        name = name,
    },
        nil
end

---Auto-detect the first ready indexer matching the current buffer.
---@param bufnr? integer
---@return ScipMatch?, string?
function M.detect(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    local missing = {}

    for _, name in ipairs(config.get().indexer_order) do
        local indexer = M.get(name)

        if indexer ~= nil then
            local project_root = M.matching_root(indexer, bufnr)

            if project_root ~= nil then
                local match, probe_result = pipeline(name, bufnr, project_root)

                if match ~= nil then
                    return match, nil
                end

                missing[#missing + 1] = probe_result.command or probe_result.err or name
            end
        end
    end

    if #missing > 0 then
        return nil, 'Missing/unavailable SCIP indexer: ' .. table.concat(missing, ', ')
    end

    return nil, 'No configured SCIP indexer matches this buffer and project'
end

---Probe a single indexer's readiness for a buffer.
---
---This is the shared resolve-root → build-context → resolve-command →
---probe-executable pipeline previously triplicated across M.detect, health
---checks, and coverage.
---
---Executable results are memoized per configuration generation; the cache is
---dropped when config.setup()/reset() replaces the configuration table. A
---PATH change without a config reset keeps serving the cached result.
---
---@param name string Indexer name.
---@param bufnr? integer Buffer used for project-root and command resolution.
---@return ScipProbe probe `{ command, ready, err }`: command is the resolved
---executable (present even when not ready, when resolution succeeded); ready
---requires a resolved project root and an executable command; err describes
---resolution failure (`M.NO_PROJECT_ROOT` when no markers matched).
function M.probe(name, bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()

    local _, probe_result = pipeline(name, bufnr, nil)

    return probe_result
end

---Register or replace a native SCIP indexer.
---
---Registration input is external, so every validation failure returns
---`nil, err` instead of throwing (unlike the built-in definitions, whose
---shape the indexer factory asserts at require time).
---
---@param name string
---@param indexer ScipIndexer
---@return boolean? ok True on success.
---@return string? err Error description on failure.
function M.register(name, indexer)
    if type(name) ~= 'string' or name == '' then
        return nil, 'SCIP indexer name must be a non-empty string'
    end

    if type(indexer) ~= 'table' then
        return nil, 'SCIP indexer must be a table'
    end

    if type(indexer.command) ~= 'string' and type(indexer.command) ~= 'function' then
        return nil, 'SCIP indexer command must be a string or function'
    end

    if type(indexer.args) ~= 'table' and type(indexer.args) ~= 'function' then
        return nil, 'SCIP indexer args must be a table or function'
    end

    if type(indexer.filetypes) ~= 'table' then
        return nil, 'SCIP indexer filetypes must be a table'
    end

    if type(indexer.markers) ~= 'table' then
        return nil, 'SCIP indexer markers must be a table'
    end

    local cfg = config.get()

    cfg.indexers[name] = vim.deepcopy(indexer)

    if not vim.tbl_contains(cfg.indexer_order, name) then
        cfg.indexer_order[#cfg.indexer_order + 1] = name
    end

    return true
end

return M
