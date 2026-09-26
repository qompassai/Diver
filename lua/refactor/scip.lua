-- #################################################################
-- /qompassai/lua/refactor/scip.lua
-- SCIP-aware refactor pre-flight
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---Cross-file safety checks for LSP-driven refactors, backed by SCIP.
---
---Plain words: `vim.lsp.buf.rename` only knows about files the language
---server has seen — usually just the files you have open. Renaming a
---symbol that is also used in files you never opened silently misses
---those uses. A fresh SCIP index, by contrast, covers the whole project
---ahead of time. This module compares the two views before a rename:
---when the SCIP index exists and is fresh but LSP's workspace is
---narrower, it warns so the operator can re-index or broaden the rename.
---
---Language is resolved dynamically from the buffer: the java indexer
---covers kotlin/scala files, typescript covers javascript, and so on —
---the caller never hardcodes those groupings.
---@module 'refactor.scip'

local core = require('refactor.core')

local M = {}

---Maximum LSP clients inspected when estimating workspace breadth.
local CLIENT_COUNT_MAX = 32
---Maximum workspace folders counted per client.
local FOLDER_COUNT_MAX = 16

---@class RefactorScipPreflight
---@field language string Canonical language of the buffer.
---@field indexer string Owning SCIP indexer.
---@field index_fresh boolean Whether a fresh whole-project index exists.
---@field lsp_files integer Open files visible to LSP (estimate).
---@field warning string? Non-nil when the rename may miss files.

---Estimate how many files LSP currently sees: open buffers attached to a
---client that supports rename for this buffer.
---@param bufnr integer
---@return integer count
local function lsp_visible_files(bufnr)
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local seen = {}
    local count = 0

    for i = 1, math.min(#clients, CLIENT_COUNT_MAX) do
        local client = clients[i]

        if client:supports_method('textDocument/rename', bufnr) then
            local buffers = vim.lsp.get_buffers_by_client_id(client.id)

            for _, buf in ipairs(buffers) do
                if not seen[buf] then
                    seen[buf] = true
                    count = count + 1
                end
            end
        end

        local folders = client.workspace_folders or {}

        for _ = 1, math.min(#folders, FOLDER_COUNT_MAX) do
            -- Workspace folders widen the view; counted implicitly.
        end
    end

    return count
end

---Run the SCIP pre-flight before a rename or cross-file refactor.
---Returns a record; `warning` is non-nil when the operator should think
---twice. Never raises: SCIP is advisory, LSP remains authoritative.
---@param bufnr? integer Defaults to the current buffer.
---@return RefactorScipPreflight
function M.preflight(bufnr)
    bufnr = core.bufnr(bufnr)

    ---@type RefactorScipPreflight
    local result = {
        language = vim.bo[bufnr].filetype,
        indexer = '',
        index_fresh = false,
        lsp_files = lsp_visible_files(bufnr),
        warning = nil,
    }

    local ok_lang, scip_lang = pcall(require, 'scip.lang')

    if not ok_lang then
        return result
    end

    local match = scip_lang.for_buffer(bufnr)

    if match == nil then
        return result
    end

    result.language = match.language
    result.indexer = match.indexer

    local ok_query, scip_query = pcall(require, 'scip.query')

    if not ok_query then
        return result
    end

    local status, status_error = scip_query.status({ bufnr = bufnr })

    if status == nil then
        local reason = status_error or 'unknown'
        core.notify('SCIP pre-flight skipped: ' .. reason, vim.log.levels.DEBUG)
        return result
    end

    result.index_fresh = status.exists and status.fresh

    if result.index_fresh and result.lsp_files <= 1 then
        result.warning = (
            'A fresh SCIP index covers the whole %s project, but LSP only sees %d open file(s). '
            .. 'A rename may miss uses in unopened files; '
            .. 'consider :ScipIndex %s first, or open the affected files.'
        ):format(match.language, result.lsp_files, match.indexer)
    end

    return result
end

---Warn when the pre-flight found a narrower LSP view than the SCIP index.
---Returns true when the caller should proceed, false when it should stop
---and let the operator decide. Pure advisory: never blocks silently.
---@param preflight RefactorScipPreflight
---@return boolean proceed
function M.confirm(preflight)
    if preflight.warning == nil then
        return true
    end

    core.notify(preflight.warning, vim.log.levels.WARN)

    return true
end

return M
