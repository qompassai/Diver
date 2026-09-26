-- #################################################################
-- /qompassai/Diver/lua/linters/quick-lint-js.lua
-- Qompass AI Diver Native quick-lint-js Linter
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
---@source https://github.com/quick-lint/quick-lint-js
---
--- ELI5: quick-lint-js is a lightning-fast typo catcher for JavaScript. It
--- reads your file from stdin and answers in a JSON quickfix list
--- (`--output-format=vim-qflist-json`): each complaint has 1-based line and
--- column ranges, a type letter (`E` for error, `W` for warning), and an
--- error code like `E0026`. `--stdin-path` tells it which file the piped
--- code pretends to be so it picks the right language (plain JS vs JSX vs
--- TypeScript).
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'quick-lint-js'

---@class QuickLintJsItem
---@field col? integer 1-based column.
---@field end_col? integer 1-based end column.
---@field end_lnum? integer 1-based end line.
---@field lnum? integer 1-based line.
---@field nr? string Error code such as `E0026`.
---@field text? string Human-readable description.
---@field type? string `E` for error, `W` for warning.

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

---@param item QuickLintJsItem
---@return vim.Diagnostic.Set?
local function diagnostic_from_item(item)
    if type(item) ~= 'table' then
        return nil
    end

    local message = clean_message(item.text)
    local row = integer_in_range(item.lnum, 1, 2147483647)
    local column = integer_in_range(item.col, 1, 2147483647)

    if message == nil or row == nil or column == nil then
        return nil
    end

    local end_row = integer_in_range(item.end_lnum, 1, 2147483647) or row
    local end_column = integer_in_range(item.end_col, 1, 2147483647) or column
    if end_row < row or (end_row == row and end_column < column) then
        end_row = row
        end_column = column
    end

    local code = type(item.nr) == 'string' and item.nr ~= '' and item.nr or nil

    return {
        lnum = row - 1,
        end_lnum = end_row - 1,
        col = column - 1,
        end_col = max(end_column - 1, column - 1),
        severity = item.type == 'E' and ERROR or WARN,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'quick-lint-js output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or type(decoded) ~= 'table' then
        return diagnostics
    end

    local qflist = decoded.qflist
    if not vim.islist(qflist) then
        return diagnostics
    end

    for _, item in ipairs(qflist) do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local diagnostic_item = diagnostic_from_item(item)
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
        -- Machine-readable quickfix JSON; the default GNU-like text is not parsed.
        '--output-format=vim-qflist-json',
        -- Read the buffer from stdin.
        '--stdin',
        -- Lets it pick the language from the filename (JS vs JSX vs TS).
        '--stdin-path',
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
    automatic = true,

    cmd = 'quick-lint-js',

    args = args,

    append_fname = false,

    cwd = cwd,

    -- Exits 0 when clean and 1 when it found problems (`--exit-fail-on`
    -- defaults to `all`).
    exit_codes = { 0, 1 },

    parser = parse,

    root_markers = {
        'quick-lint-js.config',
        'package.json',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
