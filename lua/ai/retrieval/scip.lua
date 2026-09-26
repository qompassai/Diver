-- /qompassai/Diver/lua/ai/retrieval/scip.lua
-- Qompass AI Retrieval: SCIP Symbol Candidates (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved.
-- ----------------------------------------
--
-- Plain words: the two-stage ranker needs candidates to rank. Text
-- search finds files by words; this module finds *symbols* by language:
-- given a task language (or the current buffer), it resolves the owning
-- SCIP indexer, confirms a fresh index exists, and pulls workspace
-- symbols through the live language server scoped to that language.
-- The SCIP index is the whole-project backstop — it tells us the
-- language is indexed even for files LSP has never opened — while the
-- symbol list itself comes from LSP, which is always live.
--
-- Language is dynamic per task: 'kotlin' resolves to the java indexer,
-- 'javascript' to typescript, 'cuda' to clang, and so on through
-- `scip.lang`. Callers pass a language name or nothing (buffer
-- detection); they never hardcode indexer groupings.

local M = {}

---Maximum symbols pulled from workspace/symbol in one call.
local SYMBOL_COUNT_MAX = 256
---Maximum characters kept per symbol name.
local SYMBOL_NAME_MAX = 256

---@class AiScipCandidate
---@field name string Symbol name.
---@field kind string LSP symbol kind name.
---@field language string Canonical language.
---@field indexer string Owning SCIP indexer.
---@field location table? LSP location, when provided.

---@param kind integer LSP SymbolKind number.
---@return string name
local function kind_name(kind)
    local names = {
        [1] = 'file',
        [2] = 'module',
        [3] = 'namespace',
        [4] = 'package',
        [5] = 'class',
        [6] = 'method',
        [7] = 'property',
        [8] = 'field',
        [9] = 'constructor',
        [10] = 'enum',
        [11] = 'interface',
        [12] = 'function',
        [13] = 'variable',
        [14] = 'constant',
    }

    return names[kind] or 'unknown'
end

---Collect workspace symbols for a task language, asynchronously.
---The callback receives `(err, candidates)`. An empty candidate list is
---not an error — it just means LSP had nothing for the query.
---@param query string Symbol query text.
---@param opts? { language?: string, bufnr?: integer }
---@param callback fun(err: string?, candidates: AiScipCandidate[]?)
---@return nil
function M.symbols(query, opts, callback)
    vim.validate('callback', callback, 'function')
    opts = opts or {}

    if type(query) ~= 'string' or query == '' then
        vim.schedule(function()
            callback('query must be a non-empty string', nil)
        end)
        return
    end

    local ok_lang, scip_lang = pcall(require, 'scip.lang')

    if not ok_lang then
        vim.schedule(function()
            callback('scip.lang unavailable', nil)
        end)
        return
    end

    local match, match_error

    if opts.language ~= nil and opts.language ~= '' then
        match, match_error = scip_lang.for_language(opts.language)
    else
        match, match_error = scip_lang.for_buffer(opts.bufnr)
    end

    if match == nil then
        vim.schedule(function()
            callback(match_error or 'no SCIP indexer for task language', nil)
        end)
        return
    end

    local params = { query = query }

    vim.lsp.buf_request_all(opts.bufnr or 0, 'workspace/symbol', params, function(responses)
        ---@type AiScipCandidate[]
        local candidates = {}
        local count = 0

        for _, response in pairs(responses or {}) do
            local result = response.result

            if type(result) == 'table' then
                for _, symbol in ipairs(result) do
                    if count >= SYMBOL_COUNT_MAX then
                        break
                    end

                    if type(symbol) == 'table' and type(symbol.name) == 'string' then
                        count = count + 1
                        candidates[#candidates + 1] = {
                            name = symbol.name:sub(1, SYMBOL_NAME_MAX),
                            kind = kind_name(symbol.kind),
                            language = match.language,
                            indexer = match.indexer,
                            location = symbol.location,
                        }
                    end
                end
            end

            if count >= SYMBOL_COUNT_MAX then
                break
            end
        end

        callback(nil, candidates)
    end)
end

---Adapter for the two-stage ranker: `text_of` over SCIP candidates.
---@param candidate AiScipCandidate
---@return string
function M.text_of(candidate)
    if type(candidate) ~= 'table' then
        return ''
    end

    return ('%s %s %s'):format(
        tostring(candidate.kind or ''),
        tostring(candidate.name or ''),
        tostring(candidate.language or '')
    )
end

return M
