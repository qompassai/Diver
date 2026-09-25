-- #################################################################
-- /qompassai/Diver/lua/linters/sqruff.lua
-- Qompass AI Diver Native sqruff Linter
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
---@source https://github.com/quarylabs/sqruff
---
--- ELI5: sqruff is a fast SQL linter (a SQLFluff-like checker written in
--- Rust). `sqruff lint --format json -` reads your SQL from stdin and
--- answers in JSON: one entry per input name, each a list of violations
--- carrying a 1-based line, a 1-based column, and a start/end range written
--- like LSP (`start_line`, `start_column`, `end_line`, `end_column`), plus
--- the rule code (like `LT01`) and its description. `--format json` pins the
--- machine-readable shape; `--force` keeps it linting without a config
--- file.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'sqruff'

---@class SqruffViolation
---@field code? string Rule code such as `LT01`.
---@field description? string Human-readable description.
---@field start_line? integer 1-based line.
---@field start_column? integer 1-based column.
---@field end_line? integer 1-based line.
---@field end_column? integer 1-based column.

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

---@param violation SqruffViolation
---@return vim.Diagnostic.Set?
local function diagnostic_from_violation(violation)
    if type(violation) ~= 'table' then
        return nil
    end

    local message = clean_message(violation.description)
    local start_row = integer_in_range(violation.start_line, 1, 2147483647)
    local start_column = integer_in_range(violation.start_column, 1, 2147483647)

    if message == nil or start_row == nil or start_column == nil then
        return nil
    end

    local end_row = integer_in_range(violation.end_line, 1, 2147483647) or start_row
    local end_column = integer_in_range(violation.end_column, 1, 2147483647) or start_column

    if end_row < start_row or (end_row == start_row and end_column < start_column) then
        end_row = start_row
        end_column = start_column
    end

    local code = type(violation.code) == 'string' and violation.code ~= '' and violation.code or nil

    return {
        lnum = start_row - 1,
        end_lnum = end_row - 1,
        col = start_column - 1,
        end_col = max(end_column - 1, start_column - 1),
        severity = WARN,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'sqruff output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or type(decoded) ~= 'table' then
        return diagnostics
    end

    for _, violations in pairs(decoded) do
        if vim.islist(violations) then
            for _, violation in ipairs(violations) do
                if #diagnostics >= DIAGNOSTICS_MAX then
                    break
                end

                local item = diagnostic_from_violation(violation)
                if item ~= nil then
                    diagnostics[#diagnostics + 1] = item
                end
            end
        end
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
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

    cmd = 'sqruff',

    args = {
        'lint',
        -- Machine-readable output; the default human format is not parsed.
        '--format',
        'json',
        -- Lint even without a `.sqruff` config file.
        '--force',
        -- Read the buffer from stdin.
        '-',
    },

    append_fname = false,

    cwd = cwd,

    -- sqruff exits 0 when clean and 65 (EX_DATAERR) when it found
    -- violations.
    exit_codes = { 0, 65 },

    parser = parse,

    root_markers = {
        '.sqruff',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
