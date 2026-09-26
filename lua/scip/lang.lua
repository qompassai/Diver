-- #################################################################
-- /qompassai/lua/scip/lang.lua
-- Qompass AI SCIP Language Resolver
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
---Dynamic language resolution for SCIP indexers.
---
---Plain words: several SCIP indexers cover more than one language — the
---java indexer handles Java, Kotlin, Scala, and sbt; typescript handles
---TypeScript and JavaScript; clang handles C, C++, CUDA, Objective-C;
---dotnet handles C#, F#, and Visual Basic. Every consumer (AI builder,
---refactor, BSP, retrieval) needs to ask "which indexer owns *this*
---language?" without hardcoding the mapping. This module is that answer:
---it inverts the indexer filetype tables into a language → indexer map at
---load time and resolves tasks (buffers, filetypes, language names) to the
---owning indexer dynamically.
---
---A "language" here is the canonical filetype string (`rust`, `kotlin`,
---`cpp`). Human aliases (`c++`, `c#`, `f#`) are normalized before lookup.
---@module 'scip.lang'

local registry = require('scip.registry')

local M = {}

---Maximum languages reported by `M.languages()`. Bounds the inverted map.
local LANGUAGE_COUNT_MAX = 128

---Human aliases normalized to canonical filetype strings before lookup.
---@type table<string, string>
local LANGUAGE_ALIASES = {
    ['c++'] = 'cpp',
    ['c#'] = 'cs',
    ['csharp'] = 'cs',
    ['f#'] = 'fsharp',
    ['golang'] = 'go',
    ['js'] = 'javascript',
    ['ts'] = 'typescript',
    ['py'] = 'python',
    ['rb'] = 'ruby',
    ['rs'] = 'rust',
    ['vb.net'] = 'vb',
    ['visual basic'] = 'vb',
}

---@class ScipLanguageMatch
---@field indexer string Owning indexer name.
---@field language string Canonical language (filetype).
---@field filetypes string[] Every filetype the owning indexer covers.

---Normalize a human language name to the canonical filetype string.
---@param language string
---@return string canonical
local function normalize(language)
    local lowered = language:lower():gsub('^%s+', ''):gsub('%s+$', '')
    return LANGUAGE_ALIASES[lowered] or lowered
end

---Build the inverted filetype → indexer map from the live registry.
---@return table<string, string> map filetype to indexer name
local function build_map()
    local map = {}
    local count = 0

    for _, name in ipairs(registry.names()) do
        local indexer = registry.get(name)

        if indexer ~= nil then
            for _, filetype in ipairs(registry.filetypes(indexer)) do
                if map[filetype] == nil then
                    map[filetype] = name
                    count = count + 1

                    assert(count <= LANGUAGE_COUNT_MAX, 'SCIP language map overflow')
                end
            end
        end
    end

    return map
end

---@type table<string, string>? Cached filetype → indexer map.
local language_map = nil

---Return the cached filetype → indexer map, building it on first use.
---@return table<string, string>
local function get_map()
    if language_map == nil then
        language_map = build_map()
    end

    return language_map
end

---Forget the cached map. Called when indexers are registered at runtime.
---@return nil
function M.invalidate()
    language_map = nil
end

---Resolve the owning indexer for a filetype or language name.
---@param filetype string Filetype or human language name.
---@return ScipLanguageMatch?, string?
function M.for_filetype(filetype)
    if type(filetype) ~= 'string' or filetype == '' then
        return nil, 'filetype must be a non-empty string'
    end

    local canonical = normalize(filetype)
    local indexer_name = get_map()[canonical]

    if indexer_name == nil then
        return nil, 'no SCIP indexer covers language: ' .. canonical
    end

    local indexer = registry.get(indexer_name)

    if indexer == nil then
        return nil, 'SCIP indexer went missing: ' .. indexer_name
    end

    return {
        indexer = indexer_name,
        language = canonical,
        filetypes = registry.filetypes(indexer),
    },
        nil
end

---Resolve the owning indexer for a language name, accepting aliases.
---@param language string e.g. 'rust', 'kotlin', 'c++', 'c#'.
---@return ScipLanguageMatch?, string?
function M.for_language(language)
    return M.for_filetype(language)
end

---Resolve the owning indexer for a buffer via registry auto-detection.
---Unlike `for_filetype`, this also verifies the project root markers match,
---so the indexer is actually usable for this buffer — not just nominally
---covering its filetype.
---@param bufnr? integer Defaults to the current buffer.
---@return ScipLanguageMatch?, string?
function M.for_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if type(bufnr) ~= 'number' or bufnr < 1 then
        return nil, 'bufnr must be a positive integer'
    end

    local match, detect_error = registry.detect(bufnr)

    if match == nil then
        return nil, detect_error or 'no SCIP indexer matches this buffer'
    end

    local filetype = vim.bo[bufnr].filetype

    return {
        indexer = match.name,
        language = normalize(filetype),
        filetypes = registry.filetypes(match.indexer),
    },
        nil
end

---List every covered language and its owning indexer, sorted by language.
---@return { language: string, indexer: string }[]
function M.languages()
    local map = get_map()
    local languages = {}

    for filetype, indexer_name in pairs(map) do
        languages[#languages + 1] = { language = filetype, indexer = indexer_name }
    end

    table.sort(languages, function(a, b)
        return a.language < b.language
    end)

    return languages
end

---Return the indexer names covering more than one language.
---@return table<string, string[]> indexer name to its languages
function M.multi_language()
    local by_indexer = {}

    for _, entry in ipairs(M.languages()) do
        local list = by_indexer[entry.indexer]

        if list == nil then
            list = {}
            by_indexer[entry.indexer] = list
        end

        list[#list + 1] = entry.language
    end

    local multi = {}

    for name, list in pairs(by_indexer) do
        if #list > 1 then
            table.sort(list)
            multi[name] = list
        end
    end

    return multi
end

return M
