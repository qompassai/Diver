-- #################################################################
-- /qompassai/Diver/lua/linters/flake8.lua
-- Qompass AI Diver Native Flake8 Linter
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
---@source https://github.com/PyCQA/flake8
---
--- ELI5: Flake8 is a style referee for Python. It checks your code against
--- the community rulebook (line length, unused imports, bad spacing) and
--- reports each foul as `file:line:column:CODE:message`. `--format=...` is
--- passed explicitly because Flake8's default layout is harder to parse, and
--- `--no-show-source` keeps it from echoing the offending source line.
--- `--stdin-display-name` tells it which filename to print for the code it
--- reads from stdin (the `-` at the end). Everything is a warning: Flake8
--- flags style, not crashes.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'flake8'

-- path:row:col:CODE:text (the path part is skipped; stdin names it)
local LINE_PATTERN = '^.-:(%d+):(%d+):(%w+):(.+)$'

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

    local row, column, code, message = line:match(LINE_PATTERN)

    if row == nil then
        return nil
    end

    local parsed_row = integer_in_range(row, 1, 2147483647)
    local parsed_column = integer_in_range(column, 1, 2147483647)
    local cleaned = clean_message(message)

    if parsed_row == nil or parsed_column == nil or cleaned == nil then
        return nil
    end

    return {
        lnum = parsed_row - 1,
        end_lnum = parsed_row - 1,
        col = max(parsed_column - 1, 0),
        end_col = parsed_column,
        severity = WARN,
        source = SOURCE,
        code = code ~= '' and code or nil,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'flake8 output exceeded maximum size')

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
---@return string[]
local function args(context)
    assert(context.filename ~= '')

    return {
        -- Pin the machine-readable layout; the default is human-oriented.
        '--format=%(path)s:%(row)d:%(col)d:%(code)s:%(text)s',
        -- Do not echo the offending source line after each finding.
        '--no-show-source',
        -- Filename to report for the stdin payload.
        '--stdin-display-name',
        context.filename,
        -- Read the buffer from stdin.
        '-',
    }
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

    cmd = 'flake8',

    args = args,

    append_fname = false,

    cwd = cwd,

    -- Flake8 exits 0 when clean and 1 when it found violations.
    exit_codes = { 0, 1 },

    parser = parse,

    root_markers = {
        '.flake8',
        'setup.cfg',
        'tox.ini',
        'pyproject.toml',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
