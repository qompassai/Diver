-- /qompassai/Diver/lua/ai/dataaccess/scip.lua
-- Qompass AI Data Access: SCIP Index Metadata (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- Managed read-only metadata about SCIP indexes for AI agents.
--
-- Plain words: agents ask the data layer "what do you know?". Databases
-- answer through the SQL adapters; SCIP indexes answer through this
-- module — which projects have an index, for which language, and whether
-- it is fresh. It is read-only by construction: there is no write path,
-- no query language to inject into, and every root is validated before
-- the filesystem is touched.
--
-- Roots are validated exactly like other dataaccess targets: non-empty
-- absolute paths with no `..` segments. Results are bounded.

local M = {}

---Maximum roots scanned in one inventory call.
local ROOT_COUNT_MAX = 64
---Maximum path segments scanned while rejecting `..`.
local PATH_SEGMENT_COUNT_MAX = 256

---@class DataAccessScipEntry
---@field root string Project root.
---@field language string Canonical language.
---@field indexer string Owning SCIP indexer.
---@field exists boolean Whether index.scip exists.
---@field fresh boolean Whether the index is fresh.
---@field size_bytes integer? Index size when it exists.

---Validate a project root the same way other dataaccess targets are.
---@param root string
---@return string? normalized Nil when invalid.
local function validate_root(root)
    if type(root) ~= 'string' or root == '' then
        return nil
    end

    if root:sub(1, 1) ~= '/' then
        return nil
    end

    local segments = 0

    for part in root:gmatch('[^/]+') do
        segments = segments + 1

        if segments > PATH_SEGMENT_COUNT_MAX then
            return nil
        end

        if part == '..' then
            return nil
        end
    end

    return vim.fs.normalize(root)
end

---Report SCIP index metadata for one project root and language.
---@param root string Project root.
---@param language? string Language; defaults to buffer detection.
---@return DataAccessScipEntry?, string?
function M.status_for_root(root, language)
    local normalized = validate_root(root)

    if normalized == nil then
        return nil, 'invalid project root'
    end

    local ok_query, scip_query = pcall(require, 'scip.query')

    if not ok_query then
        return nil, 'scip.query unavailable'
    end

    local status, status_error = scip_query.status({ root = normalized, language = language })

    if status == nil then
        return nil, status_error or 'could not determine SCIP status'
    end

    return {
        root = normalized,
        language = status.language,
        indexer = status.indexer,
        exists = status.exists,
        fresh = status.fresh,
        size_bytes = status.size_bytes,
    },
        nil
end

---Report SCIP index metadata for many roots, one language each.
---Invalid roots are skipped, not fatal: the inventory is advisory.
---@param specs { root: string, language?: string }[]
---@return DataAccessScipEntry[]
function M.inventory(specs)
    local entries = {}

    if type(specs) ~= 'table' then
        return entries
    end

    for i = 1, math.min(#specs, ROOT_COUNT_MAX) do
        local spec = specs[i]

        if type(spec) == 'table' and type(spec.root) == 'string' then
            local entry = M.status_for_root(spec.root, spec.language)

            if entry ~= nil then
                entries[#entries + 1] = entry
            end
        end
    end

    return entries
end

return M
