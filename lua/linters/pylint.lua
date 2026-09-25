-- #################################################################
-- /qompassai/Diver/lua/linters/pylint.lua
-- Qompass AI Diver Native Pylint Linter
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
---@source https://github.com/pylint-dev/pylint
---
--- ELI5: Pylint is the strict teacher of Python linters. It reads your file
--- from stdin (`--from-stdin` plus the filename so messages name the right
--- file) and answers in JSON (`-f json`), one object per complaint with the
--- rule symbol, message, and positions. Pylint's exit code is a bitmask
--- (fatal=1, error=2, warning=4, refactor=8, convention=16), so every exit
--- code is accepted and the JSON decides what is real. It is slow on big
--- files, so it only runs when you ask it to (see `manual_linters`).
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 16 * 1024 * 1024
local TIMEOUT_MS = 120000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'pylint'

local SEVERITIES = {
    convention = HINT,
    error = ERROR,
    fatal = ERROR,
    info = INFO,
    refactor = INFO,
    warning = WARN,
}

---@class PylintMessage
---@field column? integer 0-based column.
---@field endColumn? integer 0-based end column; may be null.
---@field line? integer 1-based line.
---@field message? string Human-readable description.
---@field message-id? string Rule id such as `C0301`.
---@field symbol? string Rule symbol such as `line-too-long`.
---@field type? string One of fatal, error, warning, convention, refactor, info.

---@param value any
---@param minimum integer
---@param maximum integer
---@return integer?
local function integer_in_range(value, minimum, maximum)
    assert(minimum >= 0)
    assert(maximum >= minimum)

    if type(value) ~= 'number' or value ~= floor(value) then
        return nil
    end

    if value < minimum or value > maximum then
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

---@param item PylintMessage
---@return vim.Diagnostic.Set?
local function diagnostic_from_message(item)
    if type(item) ~= 'table' then
        return nil
    end

    local message = clean_message(item.message)
    local row = integer_in_range(item.line, 1, 2147483647)
    local column = integer_in_range(item.column, 0, 2147483647)
    local severity = SEVERITIES[item.type]

    if message == nil or row == nil or column == nil or severity == nil then
        return nil
    end

    local end_column = integer_in_range(item.endColumn, 0, 2147483647) or column
    if end_column < column then
        end_column = column
    end

    local symbol = type(item.symbol) == 'string' and item.symbol ~= '' and item.symbol or nil
    local code = type(item['message-id']) == 'string' and item['message-id'] or symbol
    if symbol ~= nil then
        message = ('%s (%s)'):format(message, symbol)
    end

    return {
        lnum = row - 1,
        end_lnum = row - 1,
        col = column,
        end_col = max(end_column, column),
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

    assert(#output <= OUTPUT_BYTES_MAX, 'pylint output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or not vim.islist(decoded) then
        return diagnostics
    end

    for _, item in ipairs(decoded) do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local diagnostic_item = diagnostic_from_message(item)
        if diagnostic_item ~= nil then
            diagnostics[#diagnostics + 1] = diagnostic_item
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
        -- Machine-readable output; the default text layout is not parsed.
        '-f',
        'json',
        -- Read the buffer from stdin; the filename labels the messages.
        '--from-stdin',
        context.filename,
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
    cmd = 'pylint',

    args = args,

    append_fname = false,

    cwd = cwd,

    -- Pylint's exit code is a bitmask of finding kinds (fatal=1, error=2,
    -- warning=4, refactor=8, convention=16, usage error=32), so no single
    -- exit code means failure; the JSON output decides.
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        'pylintrc',
        '.pylintrc',
        'pyproject.toml',
        'setup.cfg',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
