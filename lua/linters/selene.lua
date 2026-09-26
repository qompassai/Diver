-- #################################################################
-- /qompassai/Diver/lua/linters/selene.lua
-- Qompass AI Diver Native Selene Linter
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
---@source https://github.com/Kampfkarren/selene
---
--- ELI5: Selene is a spell-checker for Lua code, built for Roblox and plain
--- Lua alike. It reads your file from stdin (the `-` at the end) and prints
--- one JSON object per line (`--display-style json`): each has a severity
--- word (`Error` or `Warning`), a lint code like `unused_variable`, and a
--- span with 0-based line and column numbers. A `Results:` summary trailer
--- is printed after the JSON; it is not a diagnostic and gets skipped.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'selene'

local SEVERITIES = {
    Error = ERROR,
    Warning = WARN,
}

---@class SeleneSpan
---@field start_line? integer 0-based line.
---@field start_column? integer 0-based column.
---@field end_line? integer 0-based line.
---@field end_column? integer 0-based column.

---@class SeleneFinding
---@field code? string Lint code such as `unused_variable`.
---@field message? string Human-readable description.
---@field primary_label? { span?: SeleneSpan, message?: string }
---@field severity? string `Error` or `Warning`.

---@param value any
---@param minimum integer
---@return integer?
local function integer_at_least(value, minimum)
    assert(minimum >= 0)

    if type(value) ~= 'number' or value ~= floor(value) then
        return nil
    end

    if value < minimum then
        return nil
    end

    ---@cast value integer
    return value
end

---@param value any
---@return string?
local function clean_message(value)
    if type(value) ~= 'string' or value == '' then
        return nil
    end

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

    local ok, decoded = pcall(vim.json.decode, line)
    if not ok or type(decoded) ~= 'table' then
        -- The non-JSON `Results:` summary trailer lands here; skip it.
        return nil
    end

    ---@cast decoded SeleneFinding

    local message = clean_message(decoded.message)
    local severity = SEVERITIES[decoded.severity]
    local label = decoded.primary_label
    local span = type(label) == 'table' and label.span or nil

    if message == nil or severity == nil or type(span) ~= 'table' then
        return nil
    end

    local start_row = integer_at_least(span.start_line, 0)
    local start_column = integer_at_least(span.start_column, 0)
    local end_row = integer_at_least(span.end_line, 0)
    local end_column = integer_at_least(span.end_column, 0)

    if start_row == nil or start_column == nil or end_row == nil or end_column == nil then
        return nil
    end

    if end_row < start_row or (end_row == start_row and end_column < start_column) then
        end_row = start_row
        end_column = start_column
    end

    local label_message = clean_message(type(label) == 'table' and label.message or nil)
    if label_message ~= nil then
        message = message .. ' ' .. label_message
    end

    local code = type(decoded.code) == 'string' and decoded.code ~= '' and decoded.code or nil

    return {
        lnum = start_row,
        end_lnum = end_row,
        col = start_column,
        end_col = max(end_column, start_column),
        severity = severity,
        source = SOURCE,
        code = code,
        message = message,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'selene output exceeded maximum size')

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

    cmd = 'selene',

    args = {
        -- One JSON object per line; the default rich text is not parsed.
        '--display-style',
        'json',
        -- Read the buffer from stdin.
        '-',
    },

    append_fname = false,

    cwd = cwd,

    -- Selene exits nonzero when it found problems; that is the normal
    -- diagnostic path.
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        'selene.toml',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
