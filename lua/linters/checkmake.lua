-- #################################################################
-- /qompassai/lua/linters/checkmake.lua
-- Qompass AI Checkmake
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
---@source https://github.com/checkmake/checkmake

local diagnostic = vim.diagnostic
local fs = vim.fs

local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class CheckmakeViolation
---@field file_name? string
---@field line_number? integer
---@field rule? string
---@field violation? string

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

---@param violation CheckmakeViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(
        violation,
        filename,
        root
)
        local path = violation.file_name

        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local line =
                math.max(
                        integer(violation.line_number, 1) - 1,
                        0
                )

        local rule = violation.rule
        local message = violation.violation

        if type(message) ~= 'string' or message == '' then
                message = 'checkmake rule violation'
        end

        if type(rule) ~= 'string' or rule == '' then
                rule = nil
        end

        return {
                lnum = line,
                end_lnum = line,
                col = 0,
                end_col = 1,
                message = message,
                severity = WARN,
                source = 'checkmake',
                code = rule,
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
                'checkmake parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')
        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'checkmake output exceeded maximum size'
        )

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        ---@cast decoded CheckmakeViolation[]

        local filename = fs.normalize(context.filename)
        local root = fs.normalize(context.root)

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local violations_count =
                math.min(#decoded, DIAGNOSTICS_MAX)

        for index = 1, violations_count do
                local violation = decoded[index]

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

return ---@type Linter
{
        automatic = false,

        cmd = 'checkmake',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        '--output',
                        'json',
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
                'checkmake.ini',
                'GNUmakefile',
                'Makefile',
                'makefile',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}