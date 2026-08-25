-- #################################################################
-- /qompassai/lua/linters/panache.lua
-- Qompass AI Panache
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
---@source https://github.com/jolars/panache

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class PanacheViolation
---@field code string
---@field column integer
---@field file string
---@field line integer
---@field message string
---@field severity string

---@type table<string, integer>
local severities = {
        error = ERROR,
        info = INFO,
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

        if path == '<stdin>' or path == '-' then
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

---@param line string
---@return PanacheViolation?
local function parse_line(line)
        if line == '' then
                return nil
        end

        local file,
                line_number,
                column_number,
                level,
                code,
                message =
                line:match(
                        '^(.+):(%d+):(%d+): '
                        .. '([%a]+)%[([^%]]+)%]: (.+)$'
                )

        if
                file == nil
                or line_number == nil
                or column_number == nil
                or level == nil
                or code == nil
                or message == nil
        then
                return nil
        end

        return {
                file = file,
                line = integer(line_number, 1),
                column = integer(column_number, 1),
                severity = level,
                code = code,
                message = message,
        }
end

---@param violation PanacheViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(
        violation,
        filename,
        root
)
        if
                not belongs_to_buffer(
                        violation.file,
                        filename,
                        root
                )
        then
                return nil
        end

        local start_line =
                math.max(
                        integer(violation.line, 1) - 1,
                        0
                )

        local start_column =
                math.max(
                        integer(violation.column, 1) - 1,
                        0
                )

        return {
                lnum = start_line,
                end_lnum = start_line,
                col = start_column,
                end_col = start_column + 1,
                message = violation.message,
                severity = severity(violation.severity),
                source = 'panache',
                code = violation.code,
                user_data = {
                        tool = 'panache',
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
                'panache parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'panache output exceeded maximum size'
        )

        local filename = fs.normalize(context.filename)
        local root = fs.normalize(context.root)

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                local violation = parse_line(line)

                if violation ~= nil then
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

return ---@type Linter
{
        automatic = false,

        cmd = 'panache',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        '--no-cache',
                        '--no-color',
                        'lint',
                        '--message-format',
                        'short',
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
                '.panache.toml',
                'panache.toml',
                '.config/panache.toml',
                '_quarto.yml',
                '.quarto.yml',
                'quarto.yml',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}