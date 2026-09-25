-- #################################################################
-- /qompassai/Diver/lua/linters/markdownlint-cli2.lua
-- Qompass AI Diver Native markdownlint-cli2 Linter
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
---@source https://github.com/DavidAnson/markdownlint-cli2
---
--- ELI5: markdownlint-cli2 checks your Markdown against a style guide
--- (trailing spaces, heading levels, line length, ...). It reads the buffer
--- from stdin (the `-` at the end) and prints one line per problem:
--- `stdin:3:28 error MD009/no-trailing-spaces Trailing spaces [Expected: 0
--- or 2; Actual: 1]`. The adapter reads the 1-based line/column, the rule
--- id (`MD009/no-trailing-spaces`), and the description from that line.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 60000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'markdownlint-cli2'

local SEVERITIES = {
    error = ERROR,
    warning = WARN,
}

-- stdin:3:28 error MD009/no-trailing-spaces Trailing spaces [...]
-- The rule token and message are separated by the first space after it.
local LINE_PATTERN = '^.-:(%d+):(%d+)%s+(%w+)%s+([%w%-/]+)%s+(.+)$'

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

    local row, column, severity_word, rule, message = line:match(LINE_PATTERN)

    if row == nil then
        return nil
    end

    local parsed_row = integer_in_range(row, 1, 2147483647)
    local parsed_column = integer_in_range(column, 1, 2147483647)
    local severity = SEVERITIES[severity_word]
    local cleaned = clean_message(message)

    if parsed_row == nil or parsed_column == nil or severity == nil or cleaned == nil then
        return nil
    end

    return {
        lnum = parsed_row - 1,
        end_lnum = parsed_row - 1,
        col = max(parsed_column - 1, 0),
        end_col = parsed_column,
        severity = severity,
        source = SOURCE,
        code = rule,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'markdownlint-cli2 output exceeded maximum size')

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

    cmd = 'markdownlint-cli2',

    args = {
        -- Read the buffer from stdin.
        '-',
    },

    append_fname = false,

    cwd = cwd,

    -- Exits 1 when it found problems; that is the normal diagnostic path.
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        '.markdownlint-cli2.jsonc',
        '.markdownlint-cli2.yaml',
        '.markdownlint.jsonc',
        '.markdownlint.yaml',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
