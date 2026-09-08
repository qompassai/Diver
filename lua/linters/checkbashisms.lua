-- #################################################################
-- /qompassai/Diver/lua/linters/checkbashisms.lua
-- Qompass AI Diver Native Checkbashisms Linter
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
local WARN = diagnostic.severity.WARN
local MAX_DIAGNOSTICS = 1024
local MAX_LINES = 4096
local MAX_OUTPUT_BYTES = 256 * 1024
local MIN_INPUT_POSITION = 1
local SOURCE = 'checkbashisms'
local CODE = 'possible-bashism'
local OUTPUT_LINE_PATTERN = '^(.-):(%d+):(%d+):%s*warning:%s*possible bashism;%s*(.+)$'
---@param value unknown
---@return integer?
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
---@param value string
---@return string
local function trim(value)
    assert(type(value) == 'string', 'value must be a string')

    return (value:gsub('^%s*(.-)%s*$', '%1'))
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
---@param bufnr integer
---@param line_number integer
---@param start_column integer
---@param message string
---@return vim.Diagnostic
local function make_diagnostic(bufnr, line_number, start_column, message)
    assert(bufnr >= 0, 'bufnr out of bounds')

    assert(line_number >= MIN_INPUT_POSITION, 'line_number out of bounds')

    assert(start_column >= MIN_INPUT_POSITION, 'start_column out of bounds')

    assert(type(message) == 'string' and message ~= '', 'message must not be empty')

    --
    -- checkbashisms reports one-based positions.
    -- Neovim diagnostics use zero-based positions.
    --
    local lnum = line_number - 1

    local col = start_column - 1

    return {
        bufnr = bufnr,

        lnum = lnum,
        end_lnum = lnum,

        col = col,
        end_col = col + 1,

        message = message,

        severity = WARN,

        source = SOURCE,
        code = CODE,
    }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    assert(type(context) == 'table', 'checkbashisms parser requires a LintContext')

    ---@cast context LintContext
    assert(type(context.bufnr) == 'number', 'context.bufnr must be a number')
    assert(context.bufnr >= 0, 'context.bufnr out of bounds')
    local safe_output = bounded_output(output)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}
    local line_count = 0
    for line in
        vim.gsplit(safe_output, '\n', {
            plain = true,
            trimempty = true,
        })
    do
        line_count = line_count + 1

        if line_count > MAX_LINES then
            break
        end

        if #diagnostics >= MAX_DIAGNOSTICS then
            break
        end

        local _filename, line_text, column_text, message = line:match(OUTPUT_LINE_PATTERN)

        if line_text ~= nil and column_text ~= nil and message ~= nil then
            local lnum = parse_positive_integer(line_text)

            local col = parse_positive_integer(column_text)

            message = trim(message)

            if lnum ~= nil and col ~= nil and message ~= '' then
                diagnostics[#diagnostics + 1] = make_diagnostic(context.bufnr, lnum, col, message)
            end
        end
    end

    assert(#diagnostics <= MAX_DIAGNOSTICS, 'diagnostic limit exceeded')

    return diagnostics
end

---@param context LintContext
---@return string
local function resolve_cwd(context)
    assert(type(context) == 'table', 'context must be a table')

    assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

    assert(type(context.cwd) == 'string' and context.cwd ~= '', 'context.cwd must be a non-empty string')

    local dirname = fs.dirname(context.filename)

    if dirname == nil or dirname == '' then
        return context.cwd
    end

    return fs.normalize(dirname)
end

return ---@type Linter
{
    automatic = false,

    cmd = {
        'checkbashisms',
        'checkbashisms.pl',
    },

    args = {
        '--lint',
    },

    append_fname = true,

    cwd = resolve_cwd,

    --
    -- checkbashisms returns nonzero when portability problems are found.
    -- Those are normal diagnostic-producing results.
    --
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        'Makefile',

        'debian/control',
        'debian/rules',

        '.git',
    },

    stdin = false,
    stream = 'stdout',
    timeout = 30000,
}
