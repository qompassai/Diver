-- #################################################################
-- /qompassai/Diver/lua/linters/mypy.lua
-- Qompass AI Diver Native Mypy Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/python/mypy
---
--- ELI5: Mypy is a picky proofreader for Python's type hints. If you say a
--- variable holds a number and later hand it text, mypy complains. It cannot
--- read from stdin, so it checks the file saved on disk (write the buffer
--- first). The flags below force one diagnostic per line in a strict
--- `file:line:col:end_line:end_col: severity: message [code]` shape:
--- `--show-column-numbers` and `--show-error-end` add the positions,
--- `--hide-error-context` drops the code snippets, `--no-color-output` and
--- `--no-pretty` keep the output plain, and `--no-error-summary` drops the
--- "found N errors" trailer.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 60000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'mypy'

local SEVERITIES = {
    error = ERROR,
    note = HINT,
    warning = WARN,
}

-- file:line:col:end_line:end_col: severity: message [code]
local LINE_PATTERN = '^(.-):(%d+):(%d+):(%d+):(%d+):%s*(%a+):%s*(.-)%s*%[([%w%-]+)%]%s*$'

---@param value string
---@param minimum integer
---@param maximum integer
---@return integer?
local function integer_in_range(value, minimum, maximum)
    assert(minimum >= 0)
    assert(maximum >= minimum)

    local parsed = tonumber(value)

    if parsed == nil or parsed ~= floor(parsed) then
        return nil
    end

    if parsed < minimum or parsed > maximum then
        return nil
    end

    ---@cast parsed integer
    return parsed
end

---@param value string
---@return string?
local function clean_message(value)
    assert(type(value) == 'string')

    local message = vim.trim(value:gsub('[%z\1-\8\11-\31\127]', ' '))

    if message == '' then
        return nil
    end

    if #message > MESSAGE_LENGTH_MAX then
        message = message:sub(1, MESSAGE_LENGTH_MAX) .. '…'
    end

    return message
end

---@param line string
---@return vim.Diagnostic.Set?
local function parse_line(line)
    assert(type(line) == 'string')

    if line == '' or #line > LINE_LENGTH_MAX then
        return nil
    end

    local _, row, column, end_row, end_column, severity_name, message, code = line:match(LINE_PATTERN)

    if row == nil then
        return nil
    end

    local parsed_row = integer_in_range(row, 1, 2147483647)
    local parsed_column = integer_in_range(column, 0, 2147483647)
    local parsed_end_row = integer_in_range(end_row, 1, 2147483647)
    local parsed_end_column = integer_in_range(end_column, 0, 2147483647)
    local cleaned = clean_message(message)
    local severity = SEVERITIES[severity_name]

    if parsed_row == nil or parsed_column == nil or cleaned == nil or severity == nil then
        return nil
    end

    parsed_end_row = parsed_end_row or parsed_row
    parsed_end_column = parsed_end_column or parsed_column
    if parsed_end_row < parsed_row or (parsed_end_row == parsed_row and parsed_end_column < parsed_column) then
        parsed_end_row = parsed_row
        parsed_end_column = parsed_column
    end

    return {
        lnum = parsed_row - 1,
        end_lnum = parsed_end_row - 1,
        col = max(parsed_column - 1, 0),
        end_col = max(parsed_end_column - 1, 0),
        severity = severity,
        source = SOURCE,
        code = code,
        message = cleaned,
    }
end

---@param output string
---@param _ LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    if output == '' then
        return diagnostics
    end

    assert(#output <= OUTPUT_BYTES_MAX, 'mypy output exceeded maximum size')

    for line in output:gmatch('[^\r\n]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local item = parse_line(line)
        if item ~= nil then
            diagnostics[#diagnostics + 1] = item
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX)

    return diagnostics
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

return ---@type Linter
{
    automatic = true,

    cmd = 'mypy',

    -- Mypy has no stdin mode; every flag below pins one output detail so the
    -- parser never depends on a human-friendly default.
    args = {
        '--show-column-numbers',
        '--show-error-end',
        '--hide-error-context',
        '--no-color-output',
        '--no-error-summary',
        '--no-pretty',
    },

    cwd = cwd,

    -- Mypy exits 0 when clean, 1 when it found issues, and 2 on crashes.
    -- A crash must stay visible, so only 0 and 1 are accepted.
    exit_codes = { 0, 1 },

    parser = parse,

    root_markers = {
        'mypy.ini',
        '.mypy.ini',
        'pyproject.toml',
        'setup.cfg',
        '.git',
    },

    -- Reads the file from disk, so the runner refuses unsaved buffers.
    stdin = false,

    stream = 'both',

    timeout = TIMEOUT_MS,
}
