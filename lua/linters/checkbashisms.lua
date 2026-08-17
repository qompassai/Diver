-- #################################################################
-- /qompassai/Diver/lua/linters/checkbashisms.lua
-- Qompass AI Diver Native Checkbashisms Linter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
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

local MAX_OUTPUT_BYTES = 262144
local MAX_LINES = 4096
local MAX_DIAGNOSTICS = 1024
local MIN_INPUT_POSITION = 1

local SOURCE = 'checkbashisms'
local CODE = 'possible-bashism'
local WARNING_SEVERITY = vim.diagnostic.severity.WARN

local OUTPUT_LINE_PATTERN =
        '^(.-):(%d+):(%d+):%s*warning:%s*possible bashism;%s*(.+)$'

---@param value any
---@return integer|nil
local function parse_positive_integer(value)
        local parsed = tonumber(value)
        if parsed == nil then
                return nil
        end

        parsed = math.floor(parsed)
        if parsed < MIN_INPUT_POSITION then
                return nil
        end

        return parsed
end

---@param line_number integer
---@param start_column integer
---@param message string
---@return vim.Diagnostic.Set
local function make_diagnostic(line_number, start_column, message)
        assert(type(line_number) == 'number', 'line_number must be a number')
        assert(type(start_column) == 'number', 'start_column must be a number')
        assert(type(message) == 'string', 'message must be a string')
        assert(line_number >= MIN_INPUT_POSITION, 'line_number out of bounds')
        assert(start_column >= MIN_INPUT_POSITION, 'start_column out of bounds')
        assert(message ~= '', 'message must not be empty')

        local lnum = line_number - 1
        local col = start_column - 1

        assert(lnum >= 0, 'lnum out of bounds')
        assert(col >= 0, 'col out of bounds')

        return {
                lnum = lnum,
                end_lnum = lnum,
                col = col,
                end_col = col + 1,
                message = message,
                severity = WARNING_SEVERITY,
                source = SOURCE,
                code = CODE,
        }
end

---@param output string
---@return string
local function bounded_output(output)
        assert(type(output) == 'string', 'output must be a string')

        if #output <= MAX_OUTPUT_BYTES then
                return output
        end

        return output:sub(1, MAX_OUTPUT_BYTES)
end

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
        local safe_output = bounded_output(output)
        local diagnostics = {}

        local line_count = 0
        local diagnostic_count = 0

        for line in vim.gsplit(safe_output, '
', { plain = true, trimempty = true }) do
                line_count = line_count + 1

                if line_count > MAX_LINES then
                        break
                end

                if diagnostic_count >= MAX_DIAGNOSTICS then
                        break
                end

                local _, lnum_text, column_text, message =
                        line:match(OUTPUT_LINE_PATTERN)

                if lnum_text ~= nil and column_text ~= nil and message ~= nil then
                        local lnum = parse_positive_integer(lnum_text)
                        local col = parse_positive_integer(column_text)

                        if lnum ~= nil and col ~= nil then
                                diagnostic_count = diagnostic_count + 1
                                diagnostics[diagnostic_count] = make_diagnostic(
                                        lnum,
                                        col,
                                        message
                                )
                        end
                end
        end

        assert(line_count >= diagnostic_count, 'diagnostic count exceeds line count')
        assert(diagnostic_count <= MAX_DIAGNOSTICS, 'diagnostic limit exceeded')

        return diagnostics
end

---@param context LintContext
---@return string
local function resolve_cwd(context)
        assert(type(context) == 'table', 'context must be a table')
        assert(type(context.filename) == 'string', 'context.filename must be a string')
        assert(type(context.cwd) == 'string', 'context.cwd must be a string')

        local dirname = vim.fs.dirname(context.filename)
        if dirname == nil or dirname == '' then
                return context.cwd
        end

        return dirname
end

return ---@type Linter
{
        cmd = {
                'checkbashisms',
                'checkbashisms.pl',
        },
        args = {
                '--lint',
        },
        append_fname = true,
        cwd = resolve_cwd,
        ignore_exitcode = true,
        parser = parse,
        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}