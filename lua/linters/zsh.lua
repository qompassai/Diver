-- #################################################################
-- /qompassai/Diver/lua/linters/zsh.lua
-- Qompass AI Diver Native Zsh Syntax Linter
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
---@source https://www.zsh.org
---
--- ELI5: This asks Zsh to read your script without running it and report
--- syntax mistakes. `--no-exec` means "check only, don't run anything",
--- `--no-rcs` and `--no-globalrcs` stop Zsh from loading your personal
--- config files (so the check doesn't depend on your machine), and
--- `/dev/stdin` feeds it the buffer through stdin. Errors look like
--- `file:line: message` on stderr, for example
--- `/dev/stdin:2: parse error near '$((1 + )'`.
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

local SOURCE = 'zsh'

-- file:line: message
local LINE_PATTERN = '^(.-):(%d+):%s*(.+)$'

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

    local _, row, message = line:match(LINE_PATTERN)

    if row == nil then
        return nil
    end

    local parsed_row = integer_in_range(row, 1, 2147483647)
    local cleaned = clean_message(message)

    if parsed_row == nil or cleaned == nil then
        return nil
    end

    -- Zsh reports a line but no reliable column; do not invent precision.
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

    assert(#output <= OUTPUT_BYTES_MAX, 'zsh output exceeded maximum size')

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

    cmd = 'zsh',

    args = {
        -- Parse the script but execute nothing.
        '--no-exec',
        -- Ignore user and global startup files; the check must not depend
        -- on this machine's Zsh configuration.
        '--no-rcs',
        '--no-globalrcs',
        -- Read the buffer from stdin (non-Windows; matches upstream).
        '/dev/stdin',
    },

    append_fname = false,

    cwd = cwd,

    -- A syntax error exits nonzero; that is the normal diagnostic path.
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        '.zshrc',
        '.zprofile',
        '.zshenv',
        '.git',
    },

    stdin = true,

    -- Zsh writes parse errors to stderr.
    stream = 'stderr',

    timeout = TIMEOUT_MS,
}
