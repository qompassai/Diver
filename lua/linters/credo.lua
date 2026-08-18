-- #################################################################
-- /qompassai/lua/linters/credo.lua
-- Qompass AI Credo
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

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 16384

---@type table<string, integer>
local severities = {
        ['↑'] = ERROR,
        ['↗'] = WARN,
        ['→'] = INFO,
        ['↘'] = HINT,
        ['↓'] = HINT,
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
                candidate = fs.normalize(fs.joinpath(root, path))
        end

        return candidate == filename
end

---@param line string
---@return string?, integer?, integer?, integer?, string?
local function parse_line(line)
        assert(#line <= LINE_LENGTH_MAX)

        local arrow
        local path
        local line_number
        local column_number
        local message

        arrow, path, line_number, column_number, message =
                line:match(
                        '^%[%a%]%s+([↑↗→↘↓])%s+(.+)%s+[^:]+:(%d+):?(%d*)%s+(.+)$'
                )

        if arrow == nil then
                return nil
        end

        local severity = severities[arrow]

        if severity == nil then
                return nil
        end

        return path,
                integer(line_number, 1),
                integer(column_number, 1),
                severity,
                message
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if output == '' then
                return {}
        end

        assert(type(context) == 'table', 'credo parser requires a LintContext')

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}

        local diagnostics_count = 0

        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                if #line <= LINE_LENGTH_MAX then
                        local path
                        local line_number
                        local column_number
                        local level
                        local message

                        path,
                        line_number,
                        column_number,
                        level,
                        message = parse_line(line)

                        if
                                path ~= nil
                                and belongs_to_buffer(path, filename, root)
                        then
                                assert(line_number ~= nil)
                                assert(column_number ~= nil)
                                assert(level ~= nil)
                                assert(message ~= nil)

                                local row = math.max(line_number - 1, 0)
                                local column = math.max(column_number - 1, 0)

                                diagnostics_count = diagnostics_count + 1

                                diagnostics[diagnostics_count] = {
                                        lnum = row,
                                        end_lnum = row,
                                        col = column,
                                        end_col = column + 1,
                                        message = message,
                                        severity = level,
                                        source = 'credo',
                                }
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

        cmd = 'mix',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        'credo',
                        'list',
                        context.filename,
                        '--read-from-stdin',
                        '--strict',
                        '--format=oneline',
                }
        end,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        exit_codes = {
                [0] = true,
                [1] = true,
        },

        parser = parse,

        root_markers = {
                '.credo.exs',
                'mix.exs',
                '.git',
        },

        stdin = true,
        stream = 'stdout',
        timeout = 30000,
}