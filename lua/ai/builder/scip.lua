-- /qompassai/Diver/lua/ai/builder/scip.lua
-- Qompass AI Builder SCIP Context (Tiger Style)
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- SCIP code-intelligence context for the plan → generate → validate →
-- review build loop, in both async (editor) and sync (headless) flavors.
--
-- Plain words: the builder asks an AI to write code. That AI writes
-- better code when it knows the precise shape of the project — which
-- symbols exist, where they are defined — instead of guessing from
-- file text alone. This module makes sure a fresh SCIP index exists
-- for the spec's language *before* generation starts, and hands the
-- pipeline a small context record (indexer, language, index path,
-- freshness) the backend can attach to its prompt.
--
-- Language is resolved dynamically per task: the spec's `language`
-- field (e.g. 'kotlin', 'c++') maps through `scip.lang` to the owning
-- indexer, so multi-language indexers (java → kotlin/scala, typescript
-- → javascript, clang → c/cpp/cuda) just work without the caller
-- knowing the grouping.
--
-- Async flavor (`prepare`) never blocks the editor: index ensuring runs
-- through the SCIP layer's own async path and the callback fires on the
-- main loop. Sync flavor (`prepare_sync`) blocks up to a bounded timeout
-- and is for headless/batch callers only.

local M = {}

---Maximum languages listed in a context record.
local CONTEXT_LANGUAGES_MAX = 64

---@class BuilderScipContext
---@field indexer string Owning SCIP indexer name.
---@field language string Canonical language for this build task.
---@field index_path string Absolute path of the project index file.
---@field fresh boolean Whether the index was fresh (no re-index needed).
---@field ensured boolean Whether an index now exists and is fresh.

---@param spec table Builder spec carrying `language` and `root`.
---@return string? language Normalized language, or nil when absent.
local function spec_language(spec)
    local language = spec.language

    if type(language) ~= 'string' or language == '' then
        return nil
    end

    return language
end

---Build the context record from a resolved match and index status.
---@param match ScipLanguageMatch
---@param status ScipIndexStatus
---@return BuilderScipContext
local function make_context(match, status)
    return {
        indexer = match.indexer,
        language = match.language,
        index_path = status.index_path,
        fresh = status.fresh,
        ensured = status.exists and status.fresh,
    }
end

---Prepare SCIP context for a build task, asynchronously.
---When the spec names no language, the callback gets (nil, nil) — SCIP
---context is optional, never a hard failure for the pipeline.
---@param spec table Builder spec with optional `language`/`root`.
---@param callback fun(err: string?, ctx: BuilderScipContext?)
---@return nil
function M.prepare(spec, callback)
    vim.validate('callback', callback, 'function')

    if type(spec) ~= 'table' then
        vim.schedule(function()
            callback('spec must be a table', nil)
        end)
        return
    end

    local language = spec_language(spec)

    if language == nil then
        vim.schedule(function()
            callback(nil, nil)
        end)
        return
    end

    local ok, scip_lang = pcall(require, 'scip.lang')

    if not ok then
        vim.schedule(function()
            callback(nil, nil)
        end)
        return
    end

    local match, match_error = scip_lang.for_language(language)

    if match == nil then
        vim.schedule(function()
            callback('no SCIP indexer for language: ' .. (match_error or language), nil)
        end)
        return
    end

    local ok_query, scip_query = pcall(require, 'scip.query')

    if not ok_query then
        vim.schedule(function()
            callback(nil, nil)
        end)
        return
    end

    scip_query.ensure({ language = match.language, root = spec.root }, function(err, status)
        if err ~= nil then
            callback(err, nil)
            return
        end

        callback(nil, make_context(match, status))
    end)
end

---Prepare SCIP context for a build task, synchronously.
---Blocks up to `timeout_ms`. Headless/batch callers only.
---@param spec table Builder spec with optional `language`/`root`.
---@param timeout_ms? integer Bounded wait budget.
---@return BuilderScipContext?, string?
function M.prepare_sync(spec, timeout_ms)
    if type(spec) ~= 'table' then
        return nil, 'spec must be a table'
    end

    local language = spec_language(spec)

    if language == nil then
        return nil, nil
    end

    local ok, scip_lang = pcall(require, 'scip.lang')

    if not ok then
        return nil, nil
    end

    local match, match_error = scip_lang.for_language(language)

    if match == nil then
        return nil, 'no SCIP indexer for language: ' .. (match_error or language)
    end

    local ok_query, scip_query = pcall(require, 'scip.query')

    if not ok_query then
        return nil, nil
    end

    local status, status_error = scip_query.ensure_sync({ language = match.language, root = spec.root }, timeout_ms)

    if status == nil then
        return nil, status_error
    end

    return make_context(match, status), nil
end

---Attach SCIP context to a spec in place. Returns the context for the
---caller; a nil context means "no SCIP for this task", which is fine.
---@param spec table Builder spec (mutated: gains `scip` field).
---@param callback fun(err: string?, ctx: BuilderScipContext?)
---@return nil
function M.attach(spec, callback)
    M.prepare(spec, function(err, ctx)
        if err == nil and ctx ~= nil then
            spec.scip = ctx
        end

        callback(err, ctx)
    end)
end

---List the languages SCIP can currently provide context for.
---@return { language: string, indexer: string }[]
function M.coverage()
    local ok, scip_lang = pcall(require, 'scip.lang')

    if not ok then
        return {}
    end

    local languages = scip_lang.languages()
    local bounded = {}

    for i = 1, math.min(#languages, CONTEXT_LANGUAGES_MAX) do
        bounded[#bounded + 1] = languages[i]
    end

    return bounded
end

return M
