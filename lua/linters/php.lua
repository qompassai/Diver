-- #################################################################
-- /qompassai/Diver/lua/linters/php.lua
-- Qompass AI Diver Native PHP Syntax Linter
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
---@source https://www.php.net
---
--- ELI5: This asks PHP itself to check your file for syntax mistakes
--- without running it. `-l` means "lint only", `-d display_errors=1`
--- makes sure the error is printed, and `-d error_reporting=E_ALL` makes
--- sure no mistake is hidden. It reads the buffer from stdin (the `-` at
--- the end) and prints errors on stderr like `PHP Parse error: syntax
--- error, unexpected token "}" in - on line 3`. "in -" means stdin, which
--- is your buffer.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR

local DIAGNOSTICS_MAX = 1024
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 15000

local floor = math.floor
local type = type

local SOURCE = 'php'

-- `PHP Parse error: syntax error, unexpected token "}" in - on line 3`
-- `PHP Fatal error: ... in - on line 3`
-- The `in <file>` part names `-` for stdin; accept anything.
local LINE_PATTERN = '^PHP%s+[%w%s]*[Ee]rror:%s*(.+)%s+in%s+.+%s+on%s+line%s+(%d+)%s*$'

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

    -- Skip the "No syntax errors detected" trailer.
    if line:find('No syntax errors detected', 1, true) ~= nil then
        return nil
    end

    local message, row = line:match(LINE_PATTERN)

    if message == nil or row == nil then
        return nil
    end

    local parsed_row = integer_in_range(row, 1, 2147483647)
    local cleaned = clean_message(message)

    if parsed_row == nil or cleaned == nil then
        return nil
    end

    -- PHP reports a line but no column; do not invent precision.
    return {
        lnum = parsed_row - 1,
        end_lnum = parsed_row - 1,
        col = 0,
        end_col = 1,
        severity = ERROR,
        source = SOURCE,
        code = 'syntax',
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

    assert(#output <= OUTPUT_BYTES_MAX, 'php output exceeded maximum size')

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

    cmd = 'php',

    args = {
        -- Lint only; never execute the code.
        '-l',
        -- Make sure the error is printed even if php.ini hides it.
        '-d',
        'display_errors=1',
        -- Report every mistake, not just the default subset.
        '-d',
        'error_reporting=E_ALL',
        -- Read the buffer from stdin.
        '-',
    },

    append_fname = false,

    cwd = cwd,

    -- A syntax error exits nonzero; that is the normal diagnostic path.
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        'composer.json',
        '.git',
    },

    stdin = true,

    -- PHP writes lint errors to stderr.
    stream = 'stderr',

    timeout = TIMEOUT_MS,
}
