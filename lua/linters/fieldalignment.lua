-- #################################################################
-- /qompassai/lua/linters/fieldalignment.lua
-- Qompass AI Fieldalignment
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

local diagnostic = vim.diagnostic
local fs = vim.fs

local HINT = diagnostic.severity.HINT

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local PACKAGES_MAX = 4096
local DIAGNOSTICS_PER_PACKAGE_MAX = 4096

---@class FieldalignmentPosition
---@field Filename? string
---@field Offset? integer
---@field Line? integer
---@field Column? integer

---@class FieldalignmentSuggestedFix
---@field Message? string

---@class FieldalignmentDiagnostic
---@field posn? string
---@field message? string
---@field suggested_fixes? FieldalignmentSuggestedFix[]

---@class FieldalignmentPackage
---@field fieldalignment? FieldalignmentDiagnostic[]
---@field error? string

---@type table<string, string>
local package_cache = {}

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

---@param filename string
---@param root string
---@return string
local function package_pattern(filename, root)
        assert(filename ~= '')
        assert(root ~= '')

        local directory = fs.dirname(filename)

        local cached = package_cache[directory]
        if cached ~= nil then
                return cached
        end

        --
        -- fieldalignment works on Go packages rather than individual source
        -- files. Running "." from the file's package directory limits analysis
        -- to the package that owns the current buffer.
        --
        package_cache[directory] = '.'

        return '.'
end

---@param position string
---@return string?, integer?, integer?
local function parse_position(position)
        assert(position ~= '')

        --
        -- go/analysis JSON position strings use:
        --
        --   /path/to/foo.go:12:7
        --
        -- Parse from the right so paths containing ':' remain valid.
        --
        local path
        local line_number
        local column_number

        path, line_number, column_number =
                position:match(
                        '^(.-):(%d+):(%d+)$'
                )

        if path == nil then
                return nil
        end

        return path,
                integer(line_number, 1),
                integer(column_number, 1)
end

---@param entry FieldalignmentDiagnostic
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(entry, filename, root)
        local position = entry.posn
        local message = entry.message

        if
                type(position) ~= 'string'
                or position == ''
                or type(message) ~= 'string'
                or message == ''
        then
                return nil
        end

        local path
        local line_number
        local column_number

        path,
                line_number,
                column_number = parse_position(position)

        if
                path == nil
                or line_number == nil
                or column_number == nil
        then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local row = math.max(line_number - 1, 0)
        local column = math.max(column_number - 1, 0)

        return {
                lnum = row,
                end_lnum = row,
                col = column,
                end_col = column + 1,
                message = message,
                severity = HINT,
                source = 'fieldalignment',
                code = 'fieldalignment',
                user_data = {
                        suggested_fixes = entry.suggested_fixes,
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
                'fieldalignment parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'fieldalignment output exceeded maximum size'
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
        local packages_count = 0

        --
        -- go/analysis -json output is keyed by package import path.
        --
        for _, package_result in pairs(decoded) do
                packages_count = packages_count + 1

                if packages_count > PACKAGES_MAX then
                        break
                end

                if type(package_result) == 'table' then
                        ---@cast package_result FieldalignmentPackage

                        local entries = package_result.fieldalignment

                        if type(entries) == 'table' then
                                local entries_count = math.min(
                                        #entries,
                                        DIAGNOSTICS_PER_PACKAGE_MAX
                                )

                                for index = 1, entries_count do
                                        if diagnostics_count >= DIAGNOSTICS_MAX then
                                                break
                                        end

                                        local entry = entries[index]

                                        if type(entry) == 'table' then
                                                local item =
                                                        diagnostic_from_entry(
                                                                entry,
                                                                filename,
                                                                root
                                                        )

                                                if item ~= nil then
                                                        diagnostics_count =
                                                                diagnostics_count + 1

                                                        diagnostics[diagnostics_count] =
                                                                item
                                                end
                                        end
                                end
                        end
                end

                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end
        end

        assert(packages_count <= PACKAGES_MAX + 1)
        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'fieldalignment',

        args = function(context)
                assert(context.filename ~= '')
                assert(context.root ~= '')

                return {
                        '-json',
                        package_pattern(
                                context.filename,
                                context.root
                        ),
                }
        end,

        append_fname = false,

        cwd = function(context)
                assert(context.filename ~= '')
                assert(context.root ~= '')

                --
                -- Analyze from the current Go package rather than the project
                -- root. `fieldalignment .` then loads only that package.
                --
                return fs.dirname(
                        fs.normalize(context.filename)
                )
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                'go.work',
                'go.mod',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 60000,
}