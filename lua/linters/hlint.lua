-- #################################################################
-- /qompassai/lua/linters/hlint.lua
-- Qompass AI HLint
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

---@source https://github.com/ndmitchell/hlint

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local STRING_LENGTH_MAX = 16384

---@class HLintHint
---@field severity? string
---@field hint? string
---@field file? string
---@field startLine? integer
---@field startColumn? integer
---@field endLine? integer
---@field endColumn? integer
---@field from? string
---@field to? string
---@field note? string|string[]

---@type table<string, integer>
local severities = {
        Error = ERROR,
        Warning = WARN,
        Suggestion = HINT,
}

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
        assert(fallback >= 0)

        local parsed = tonumber(value)

        if parsed == nil then
                return fallback
        end

        return math.floor(parsed)
end

---@param value string|nil
---@return integer
local function severity(value)
        if value == nil then
                return WARN
        end

        return severities[value] or WARN
end

---@param value string|nil
---@return string?
local function bounded_string(value)
        if type(value) ~= 'string' or value == '' then
                return nil
        end

        if #value > STRING_LENGTH_MAX then
                return value:sub(1, STRING_LENGTH_MAX)
        end

        return value
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
        assert(path ~= '')
        assert(filename ~= '')
        assert(root ~= '')

        local candidate

        if fs.is_absolute(path) then
                candidate = fs.normalize(path)
        else
                candidate = fs.normalize(
                        fs.joinpath(root, path)
                )
        end

        return candidate == filename
end

---@param hint HLintHint
---@return string
local function message_from_hint(hint)
        local name = bounded_string(hint.hint)
        local from = bounded_string(hint.from)
        local to = bounded_string(hint.to)

        if name == nil then
                name = 'HLint suggestion'
        end

        if from ~= nil and to ~= nil then
                return ('%s: %s → %s'):format(
                        name,
                        from,
                        to
                )
        end

        if from ~= nil then
                return ('%s: %s'):format(
                        name,
                        from
                )
        end

        return name
end

---@param hint HLintHint
---@return string[]?
local function notes_from_hint(hint)
        local note = hint.note

        if type(note) == 'string' then
                local value = bounded_string(note)

                if value ~= nil then
                        return { value }
                end

                return nil
        end

        if type(note) ~= 'table' then
                return nil
        end

        ---@type string[]
        local notes = {}
        local notes_count = 0

        for index = 1, math.min(#note, 64) do
                local value = bounded_string(note[index])

                if value ~= nil then
                        notes_count = notes_count + 1
                        notes[notes_count] = value
                end
        end

        if notes_count == 0 then
                return nil
        end

        return notes
end

---@param hint HLintHint
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_hint(hint, filename, root)
        local path = hint.file

        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local start_line = math.max(
                integer(hint.startLine, 1) - 1,
                0
        )

        local start_column = math.max(
                integer(hint.startColumn, 1) - 1,
                0
        )

        local end_line = math.max(
                integer(
                        hint.endLine,
                        start_line + 1
                ) - 1,
                start_line
        )

        local minimum_end_column =
                end_line == start_line
                        and start_column + 1
                        or 0

        local end_column = math.max(
                integer(
                        hint.endColumn,
                        minimum_end_column + 1
                ) - 1,
                minimum_end_column
        )

        return {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = message_from_hint(hint),
                severity = severity(hint.severity),
                source = 'hlint',
                code = hint.hint,
                user_data = {
                        from = hint.from,
                        to = hint.to,
                        note = notes_from_hint(hint),
                },
        }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if output == '' then
                return {}
        end

        assert(
                type(context) == 'table',
                'hlint parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'hlint output exceeded maximum size'
        )

        local ok, decoded = pcall(
                vim.json.decode,
                output
        )

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local hints_count = math.min(
                #decoded,
                DIAGNOSTICS_MAX
        )

        for index = 1, hints_count do
                local hint = decoded[index]

                if type(hint) == 'table' then
                        ---@cast hint HLintHint

                        local entry = diagnostic_from_hint(
                                hint,
                                filename,
                                root
                        )

                        if entry ~= nil then
                                diagnostics_count =
                                        diagnostics_count + 1

                                diagnostics[diagnostics_count] =
                                        entry
                        end
                end
        end

        assert(
                diagnostics_count <= DIAGNOSTICS_MAX
        )

        assert(
                diagnostics_count == #diagnostics
        )

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'hlint',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        '--json',
                        '--no-exit-code',
                        context.filename,
                }
        end,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                '.hlint.yaml',
                'cabal.project',
                'cabal.project.local',
                'stack.yaml',
                'package.yaml',
                '*.cabal',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}