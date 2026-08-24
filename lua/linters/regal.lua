-- #################################################################
-- /qompassai/lua/linters/regal.lua
-- Qompass AI Regal
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
---@source https://github.com/open-policy-agent/regal

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class RegalLocation
---@field file? string
---@field row? integer
---@field col? integer
---@field end? RegalLocation

---@class RegalViolation
---@field category? string
---@field description? string
---@field level? string
---@field location? RegalLocation
---@field title? string

---@class RegalReport
---@field violations? RegalViolation[]

---@type table<string, integer>
local severities = {
        error = ERROR,
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
                return ERROR
        end

        return severities[level:lower()] or ERROR
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

---@param violation RegalViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(violation, filename, root)
        local location = violation.location

        if type(location) ~= 'table' then
                return nil
        end

        local path = location.file
        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local start_line = math.max(integer(location.row, 1) - 1, 0)
        local start_column = math.max(integer(location.col, 1) - 1, 0)

        local end_line = start_line
        local end_column = start_column + 1

        if type(location.end) == 'table' then
                end_line = math.max(
                        integer(location.end.row, start_line + 1) - 1,
                        start_line
                )

                local minimum_end_column =
                        end_line == start_line
                                and start_column + 1
                                or 0

                end_column = math.max(
                        integer(
                                location.end.col,
                                minimum_end_column + 1
                        ) - 1,
                        minimum_end_column
                )
        end

        local title = violation.title
        local description = violation.description

        local message

        if
                type(description) == 'string'
                and description ~= ''
        then
                message = description
        elseif type(title) == 'string' and title ~= '' then
                message = title
        else
                message = 'Regal policy violation'
        end

        return {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = message,
                severity = severity(violation.level),
                source = 'regal',
                code = title,
                user_data = {
                        category = violation.category,
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
                'regal parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')
        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'regal output exceeded maximum size'
        )

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        ---@cast decoded RegalReport

        local violations = decoded.violations
        if type(violations) ~= 'table' then
                return {}
        end

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local violations_count =
                math.min(#violations, DIAGNOSTICS_MAX)

        for index = 1, violations_count do
                local violation = violations[index]

                if type(violation) == 'table' then
                        local entry = diagnostic_from_violation(
                                violation,
                                filename,
                                root
                        )

                        if entry ~= nil then
                                diagnostics_count =
                                        diagnostics_count + 1

                                diagnostics[diagnostics_count] = entry
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

        cmd = 'regal',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        'lint',
                        '--format=json',
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
                '.regal',
                '.regal.yaml',
                'rego.mod',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}