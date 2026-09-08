-- #################################################################
-- /qompassai/Diver/lua/linters/rubocop.lua
-- Qompass AI RuboCop
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
---@source https://github.com/rubocop/rubocop

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class RubocopLocation
---@field column? integer
---@field last_column? integer
---@field last_line? integer
---@field length? integer
---@field line? integer
---@field start_column? integer
---@field start_line? integer

---@class RubocopOffense
---@field cop_name? string
---@field correctable? boolean
---@field corrected? boolean
---@field location? RubocopLocation
---@field message? string
---@field severity? string

---@class RubocopFile
---@field offenses? RubocopOffense[]
---@field path? string

---@class RubocopReport
---@field files? RubocopFile[]

---@type table<string, integer>
local severities = {
        convention = HINT,
        error = ERROR,
        fatal = ERROR,
        info = INFO,
        refactor = INFO,
        warning = WARN,
}

---@param value integer|number|string|nil
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

---@param level string|nil
---@return integer
local function severity(level)
        if level == nil then
                return WARN
        end

        return severities[level:lower()] or WARN
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
        assert(path ~= '')
        assert(filename ~= '')
        assert(root ~= '')

        if path == '-' or path == '<stdin>' then
                return true
        end

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

---@param offense RubocopOffense
---@param path string
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_offense(
        offense,
        path,
        filename,
        root
)
        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local location = offense.location

        if type(location) ~= 'table' then
                return nil
        end

        local start_line = math.max(
                integer(
                        location.start_line or location.line,
                        1
                ) - 1,
                0
        )

        local start_column = math.max(
                integer(
                        location.start_column or location.column,
                        1
                ) - 1,
                0
        )

        local end_line = math.max(
                integer(
                        location.last_line,
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
                        location.last_column,
                        minimum_end_column + 1
                ),
                minimum_end_column + 1
        )

        local message = offense.message

        if type(message) ~= 'string' or message == '' then
                message = 'RuboCop offense'
        end

        local code = offense.cop_name

        if type(code) ~= 'string' or code == '' then
                code = nil
        end

        return {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = message,
                severity = severity(offense.severity),
                source = 'rubocop',
                code = code,
                user_data = {
                        correctable = offense.correctable == true,
                        corrected = offense.corrected == true,
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
                'rubocop parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'rubocop output exceeded maximum size'
        )

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        ---@cast decoded RubocopReport

        local files = decoded.files

        if type(files) ~= 'table' then
                return {}
        end

        local filename = fs.normalize(context.filename)
        local root = fs.normalize(context.root)

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        for file_index = 1, #files do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                local file = files[file_index]

                if type(file) == 'table' then
                        local path = file.path
                        local offenses = file.offenses

                        if
                                type(path) == 'string'
                                and path ~= ''
                                and type(offenses) == 'table'
                        then
                                local offense_count =
                                        math.min(
                                                #offenses,
                                                DIAGNOSTICS_MAX
                                                        - diagnostics_count
                                        )

                                for offense_index = 1, offense_count do
                                        local offense =
                                                offenses[offense_index]

                                        if type(offense) == 'table' then
                                                local entry =
                                                        diagnostic_from_offense(
                                                                offense,
                                                                path,
                                                                filename,
                                                                root
                                                        )

                                                if entry ~= nil then
                                                        diagnostics_count =
                                                                diagnostics_count
                                                                + 1

                                                        diagnostics[diagnostics_count] =
                                                                entry
                                                end
                                        end
                                end
                        end
                end
        end

        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
        assert(context.filename ~= '')

        return {
                '--editor-mode',

                '--format',
                'json',

                '--force-exclusion',

                '--no-color',

                '--stdin',
                context.filename,
        }
end

return ---@type Linter
{
        automatic = false,

        cmd = 'rubocop',

        args = args,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                '.rubocop.yml',
                '.rubocop.yaml',
                '.rubocop',
                'Gemfile',
                'Gemfile.lock',
                'gems.rb',
                'gems.locked',
                '.ruby-version',
                '.git',
        },

        stdin = true,
        stream = 'stdout',
        timeout = 30000,
}