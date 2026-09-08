-- #################################################################
-- /qompassai/lua/linters/checkcode.lua
-- Qompass AI Checkcode
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

---@source https://github.com/graydwarf/godot-gdscript-linter

local diagnostic = vim.diagnostic
local fs = vim.fs

local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class CheckcodeIssue
---@field id? string
---@field message? string
---@field line? integer|integer[]
---@field column? integer|integer[]|integer[][]

---@class CheckcodeOutput
---@field issues? CheckcodeIssue[]

---@param value string
---@return string
local function matlab_string(value)
        assert(value ~= '')

        return value:gsub("'", "''")
end

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

---@param value any
---@param fallback integer
---@return integer
local function first_integer(value, fallback)
        if type(value) == 'number' then
                return integer(value, fallback)
        end

        if type(value) ~= 'table' then
                return fallback
        end

        local first = value[1]

        if type(first) == 'table' then
                return integer(first[1], fallback)
        end

        return integer(first, fallback)
end

---@param value any
---@param fallback integer
---@return integer
local function last_integer(value, fallback)
        if type(value) == 'number' then
                return integer(value, fallback)
        end

        if type(value) ~= 'table' then
                return fallback
        end

        local first = value[1]

        if type(first) == 'table' then
                return integer(first[2] or first[1], fallback)
        end

        return integer(value[2] or value[1], fallback)
end

---@param issue CheckcodeIssue
---@return vim.Diagnostic?
local function diagnostic_from_issue(issue)
        local message = issue.message

        if type(message) ~= 'string' or message == '' then
                return nil
        end

        local start_line = math.max(
                first_integer(issue.line, 1) - 1,
                0
        )

        local start_column = math.max(
                first_integer(issue.column, 1) - 1,
                0
        )

        local end_column = math.max(
                last_integer(issue.column, start_column + 2) - 1,
                start_column + 1
        )

        return {
                lnum = start_line,
                end_lnum = start_line,
                col = start_column,
                end_col = end_column,
                message = message,
                severity = WARN,
                source = 'checkcode',
                code = issue.id,
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
                'checkcode parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')
        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'checkcode output exceeded maximum size'
        )

        local ok, decoded = pcall(vim.json.decode, output)

        if not ok or type(decoded) ~= 'table' then
                return {}
        end

        ---@cast decoded CheckcodeOutput

        local issues = decoded.issues

        if type(issues) ~= 'table' then
                return {}
        end

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local issues_count = math.min(
                #issues,
                DIAGNOSTICS_MAX
        )

        for index = 1, issues_count do
                local issue = issues[index]

                if type(issue) == 'table' then
                        local entry = diagnostic_from_issue(issue)

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

        cmd = 'matlab',

        args = function(context)
                assert(context.filename ~= '')
                assert(context.root ~= '')

                local filename = matlab_string(
                        fs.normalize(context.filename)
                )

                --
                -- checkcode(..., '-struct', '-id', '-fullpath') returns
                -- structured Code Analyzer diagnostics.
                --
                -- jsonencode() converts that structure directly into a
                -- machine-readable payload for Neovim.
                --
                local expression = table.concat({
                        "try;",
                        ("i=checkcode('%s','-struct','-id','-fullpath');")
                                :format(filename),
                        "fprintf('%s',jsonencode(struct('issues',i)));",
                        "catch e;",
                        "fprintf(2,'%s',getReport(e,'extended','hyperlinks','off'));",
                        "exit(2);",
                        "end;",
                        "exit(0);",
                })

                return {
                        '-batch',
                        expression,
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
                'startup.m',
                'setup.m',
                'slprj',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 120000,
}