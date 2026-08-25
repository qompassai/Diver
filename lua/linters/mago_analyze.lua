-- #################################################################
-- /qompassai/Diver/lua/linters/mago_analyze.lua
-- Qompass AI Mago Analyze
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
---@source https://github.com/carthage-software/mago

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class MagoAnalyzePosition
---@field column? integer
---@field line? integer

---@class MagoAnalyzeSpan
---@field end? MagoAnalyzePosition
---@field file? string
---@field start? MagoAnalyzePosition

---@class MagoAnalyzeViolation
---@field code? string
---@field message? string
---@field severity? string
---@field span? MagoAnalyzeSpan

---@type table<string, integer>
local severities = {
        error = ERROR,
        help = HINT,
        info = INFO,
        note = INFO,
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

---@param violation MagoAnalyzeViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(
        violation,
        filename,
        root
)
        local span = violation.span

        if type(span) ~= 'table' then
                return nil
        end

        local path = span.file

        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local start = span.start
        local finish = span['end']

        local start_line = 0
        local start_column = 0

        if type(start) == 'table' then
                start_line = math.max(
                        integer(start.line, 1) - 1,
                        0
                )

                start_column = math.max(
                        integer(start.column, 1) - 1,
                        0
                )
        end

        local end_line = start_line
        local end_column = start_column + 1

        if type(finish) == 'table' then
                end_line = math.max(
                        integer(
                                finish.line,
                                start_line + 1
                        ) - 1,
                        start_line
                )

                local minimum_end_column =
                        end_line == start_line
                                and start_column + 1
                                or 0

                end_column = math.max(
                        integer(
                                finish.column,
                                minimum_end_column + 1
                        ) - 1,
                        minimum_end_column
                )
        end

        local message = violation.message

        if type(message) ~= 'string' or message == '' then
                message = 'Mago analyzer violation'
        end

        local code = violation.code

        if type(code) ~= 'string' or code == '' then
                code = nil
        end

        return {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = message,
                severity = severity(violation.severity),
                source = 'mago_analyze',
                code = code,
                user_data = {
                        analyzer = 'mago',
                },
        }
end

---@param decoded any
---@return MagoAnalyzeViolation[]
local function violations_from_json(decoded)
        if type(decoded) ~= 'table' then
                return {}
        end

        if vim.islist(decoded) then
                ---@cast decoded MagoAnalyzeViolation[]
                return decoded
        end

        if type(decoded.issues) == 'table' then
                ---@cast decoded.issues MagoAnalyzeViolation[]
                return decoded.issues
        end

        if type(decoded.diagnostics) == 'table' then
                ---@cast decoded.diagnostics MagoAnalyzeViolation[]
                return decoded.diagnostics
        end

        return {}
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
                'mago_analyze parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'mago_analyze output exceeded maximum size'
        )

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        local violations = violations_from_json(decoded)

        if #violations == 0 then
                return {}
        end

        local filename = fs.normalize(context.filename)
        local root = fs.normalize(context.root)

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local violations_count =
                math.min(#violations, DIAGNOSTICS_MAX)

        for index = 1, violations_count do
                local violation = violations[index]

                if type(violation) == 'table' then
                        local entry =
                                diagnostic_from_violation(
                                        violation,
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

        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
        assert(context.filename ~= '')

        return {
                'analyze',

                -- Analyze the live Neovim buffer rather than only
                -- the last-saved file contents.
                '--stdin-input',

                -- Machine-readable diagnostics.
                '--reporting-format',
                'json',

                -- Preserve the real logical project filename while
                -- source text itself arrives through stdin.
                context.filename,
        }
end

return ---@type Linter
{
        automatic = false,

        cmd = 'mago',

        args = args,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                'mago.toml',
                'composer.json',
                'composer.lock',
                'phpunit.xml',
                'phpunit.xml.dist',
                '.git',
        },

        stdin = true,
        stream = 'stdout',
        timeout = 30000,
}