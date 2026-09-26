-- #################################################################
-- /qompassai/lua/scip/query.lua
-- Qompass AI SCIP Index Query
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
---Read side of the SCIP layer: index presence, freshness, and ensured
---indexing for AI consumers.
---
---Plain words: generating an index (`scip.index`) is the write side. Every
---AI workflow — builder, refactor, retrieval, BSP — needs the read side:
---"is there an index for this project and language?", "is it stale?", and
---"make sure one exists before I rely on it". This module answers those
---three questions, per language, with both async (callback) and sync
---(blocking) flavors. The async flavor never blocks the editor; the sync
---flavor is for headless/batch callers that can afford to wait.
---
---Honest contract: SCIP index files are protobuf. This module does not
---parse symbol tables in Lua. Freshness is decided by comparing the index
---file mtime against the newest source file mtime under the project root
---(bounded scan). Symbol queries themselves go through `vim.lsp` against
---the live language server, scoped to the resolved language.
---@module 'scip.query'

local config = require('scip.config')
local index = require('scip.index')
local lang = require('scip.lang')
local utils = require('scip.utils')

local M = {}

---Maximum source files scanned when deciding index freshness.
local FRESHNESS_SCAN_MAX = 20000
---Maximum path depth descended during the freshness scan.
local FRESHNESS_DEPTH_MAX = 32
---Default timeout for a synchronous ensure, in milliseconds.
local ENSURE_SYNC_TIMEOUT_MS = 120000

---@class ScipIndexStatus
---@field exists boolean Whether index.scip exists under the root.
---@field fresh boolean True when the index is newer than every source file seen.
---@field index_path string Absolute path of the index file.
---@field indexer string Owning indexer name.
---@field language string Canonical language.
---@field mtime integer? Index file mtime (seconds), when it exists.
---@field size_bytes integer? Index file size, when it exists.

---@class ScipEnsureOpts
---@field bufnr? integer Buffer used for language/root detection.
---@field language? string Explicit language (overrides buffer detection).
---@field root? string Explicit project root override.
---@field timeout_ms? integer Sync-only wait budget.

---Resolve the project root and indexer for a query.
---@param opts ScipEnsureOpts
---@return string? root
---@return ScipLanguageMatch? match
---@return string? err
local function resolve_target(opts)
    local match, match_error

    if opts.language ~= nil and opts.language ~= '' then
        match, match_error = lang.for_language(opts.language)
    else
        match, match_error = lang.for_buffer(opts.bufnr)
    end

    if match == nil then
        return nil, nil, match_error
    end

    local root = opts.root

    if root == nil or root == '' then
        local ok, scip_root = pcall(require, 'scip.root')

        if not ok then
            return nil, nil, 'scip.root unavailable'
        end

        local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
        local indexer = require('scip.registry').get(match.indexer)

        if indexer == nil then
            return nil, nil, 'indexer went missing: ' .. match.indexer
        end

        root = scip_root.find(bufnr, indexer.markers)
    end

    if root == nil or root == '' then
        return nil, nil, 'no project root found for language: ' .. match.language
    end

    return vim.fs.normalize(root), match, nil
end

---Absolute path of the index file for a project root.
---@param root string
---@return string
function M.index_path(root)
    return vim.fs.joinpath(vim.fs.normalize(root), config.get().index_file)
end

---Decide whether the index is newer than the sources (bounded scan).
---@param root string Project root.
---@param index_mtime integer Index file mtime in seconds.
---@param filetypes string[] Filetypes the indexer covers.
---@return boolean fresh
local function is_fresh(root, index_mtime)
    local newest = 0
    local scanned = 0
    local stack = { { dir = root, depth = 0 } }

    while #stack > 0 and scanned < FRESHNESS_SCAN_MAX do
        local frame = table.remove(stack)
        local ok, handle = pcall(vim.uv.fs_scandir, frame.dir)

        if ok and handle ~= nil then
            while scanned < FRESHNESS_SCAN_MAX do
                local name, ftype = vim.uv.fs_scandir_next(handle)

                if name == nil then
                    break
                end

                if ftype == 'directory' and frame.depth < FRESHNESS_DEPTH_MAX then
                    if name ~= '.git' and name ~= 'target' and name ~= 'node_modules' then
                        stack[#stack + 1] = {
                            dir = vim.fs.joinpath(frame.dir, name),
                            depth = frame.depth + 1,
                        }
                    end
                elseif ftype == 'file' then
                    local ext = name:match('%.([^%.]+)$')

                    if ext ~= nil then
                        scanned = scanned + 1
                        local stat = vim.uv.fs_stat(vim.fs.joinpath(frame.dir, name))

                        if stat ~= nil and stat.mtime ~= nil then
                            local mtime_sec = math.floor(stat.mtime.sec)

                            if mtime_sec > newest then
                                newest = mtime_sec
                            end

                            if newest > index_mtime then
                                return false
                            end
                        end
                    end
                end
            end
        end
    end

    return newest <= index_mtime
end

---Report index presence and freshness for a project/language.
---@param opts ScipEnsureOpts
---@return ScipIndexStatus?, string?
function M.status(opts)
    opts = opts or {}

    local root, match, resolve_error = resolve_target(opts)

    if root == nil then
        return nil, resolve_error
    end

    ---@type ScipLanguageMatch
    local resolved = match
    local path = M.index_path(root)
    local stat = vim.uv.fs_stat(path)

    if stat == nil then
        return {
            exists = false,
            fresh = false,
            index_path = path,
            indexer = resolved.indexer,
            language = resolved.language,
        },
            nil
    end

    local mtime_sec = math.floor(stat.mtime.sec)

    return {
        exists = true,
        fresh = is_fresh(root, mtime_sec),
        index_path = path,
        indexer = resolved.indexer,
        language = resolved.language,
        mtime = mtime_sec,
        size_bytes = stat.size,
    },
        nil
end

---Ensure a fresh index exists, asynchronously. The callback fires on the
---main loop with `(err, status)`. Never blocks the editor.
---@param opts ScipEnsureOpts
---@param callback fun(err: string?, status: ScipIndexStatus?)
---@return nil
function M.ensure(opts, callback)
    vim.validate('callback', callback, 'function')
    opts = opts or {}

    local status, status_error = M.status(opts)

    if status == nil then
        vim.schedule(function()
            callback(status_error, nil)
        end)
        return
    end

    if status.exists and status.fresh then
        vim.schedule(function()
            callback(nil, status)
        end)
        return
    end

    local root, match, resolve_error = resolve_target(opts)

    if root == nil then
        vim.schedule(function()
            callback(resolve_error, nil)
        end)
        return
    end

    -- Trigger indexing through the write side, then re-stat on completion.
    -- index.run is fire-and-notify; poll the index file instead of hooking
    -- its internals.
    index.run(match.indexer, { root = root })

    local attempts = 0
    local timer = vim.uv.new_timer()

    if timer == nil then
        callback('could not create poll timer', nil)
        return
    end

    timer:start(
        500,
        500,
        vim.schedule_wrap(function()
            attempts = attempts + 1

            local fresh_status = M.status(opts)

            if fresh_status ~= nil and fresh_status.exists then
                timer:stop()
                timer:close()
                callback(nil, fresh_status)
                return
            end

            if attempts >= 240 then
                timer:stop()
                timer:close()
                callback('timed out waiting for SCIP index', nil)
            end
        end)
    )
end

---Ensure a fresh index exists, synchronously. Blocks up to `timeout_ms`.
---For headless/batch callers only; never call from a UI callback.
---@param opts ScipEnsureOpts
---@return ScipIndexStatus?, string?
function M.ensure_sync(opts)
    opts = opts or {}

    local status, status_error = M.status(opts)

    if status == nil then
        return nil, status_error
    end

    if status.exists and status.fresh then
        return status, nil
    end

    local root, match, resolve_error = resolve_target(opts)

    if root == nil then
        return nil, resolve_error
    end

    local indexer = require('scip.registry').get(match.indexer)

    if indexer == nil then
        return nil, 'indexer went missing: ' .. match.indexer
    end

    local ctx_mod = require('scip.context')
    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local ctx = ctx_mod.new(match.indexer, bufnr, root)
    local command, command_error = utils.resolve_command(indexer.command, ctx)

    if command == nil then
        return nil, command_error
    end

    local args, args_error = utils.resolve_args(indexer.args, ctx)

    if args == nil then
        return nil, args_error
    end

    local argv = { command }
    vim.list_extend(argv, args)

    local result = vim.system(argv, {
        cwd = root,
        text = true,
        timeout = opts.timeout_ms or ENSURE_SYNC_TIMEOUT_MS,
    }):wait()

    if result.code ~= 0 then
        return nil, ('indexer failed (exit %d): %s'):format(result.code, result.stderr or '')
    end

    return M.status(opts)
end

return M
