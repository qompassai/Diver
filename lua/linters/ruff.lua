-- #################################################################
-- /qompassai/Diver/lua/linters/ruff.lua
-- Qompass AI Diver Native Ruff Linter
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
---@source https://github.com/astral-sh/ruff
---
--- ELI5: Ruff is a super-fast spell-checker for Python code. You hand it your
--- file through stdin (the `-` at the end means "read what I pipe you"), and
--- it answers in JSON: a list of complaints, each with a rule code like `E501`
--- and the exact line and column. `--output-format=json` is passed explicitly
--- because Ruff's normal answer is human-readable text, which is hard for a
--- program to read reliably. `--stdin-filename` tells Ruff which file the
--- piped code pretends to be so it can find the project's settings. Rules
--- starting with `E` (style errors) or `F` (likely bugs, like undefined
--- names) are shown as errors; everything else is a warning.
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

local SOURCE = 'ruff'

---@class RuffLocation
---@field row integer 1-based line number.
---@field column integer 1-based column number.

---@class RuffFinding
---@field code? string Rule code such as `E501`.
---@field message? string Human-readable description.
---@field location? RuffLocation Start position.
---@field end_location? RuffLocation End position.

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

---@param code string?
---@return integer
local function severity_for(code)
    -- Ruff emits no severity of its own. `E` rules are style errors and `F`
    -- rules flag probable bugs (undefined names, unused imports), so both
    -- surface as errors; the rest are warnings.
    if type(code) == 'string' then
        local first = code:sub(1, 1)
        if first == 'E' or first == 'F' then
            return ERROR
        end
    end
    return WARN
end

---@param finding RuffFinding
---@return vim.Diagnostic.Set?
local function diagnostic_from_finding(finding)
    if type(finding) ~= 'table' then
        return nil
    end

    local message = clean_message(finding.message)
    local location = finding.location
    if message == nil or type(location) ~= 'table' then
        return nil
    end

    local row = integer_in_range(location.row, 1, 2147483647)
    local column = integer_in_range(location.column, 1, 2147483647)
    if row == nil or column == nil then
        return nil
    end

    local end_location = finding.end_location
    local end_row = row
    local end_column = column
    if type(end_location) == 'table' then
        end_row = integer_in_range(end_location.row, 1, 2147483647) or row
        end_column = integer_in_range(end_location.column, 1, 2147483647) or column
    end
    if end_row < row or (end_row == row and end_column < column) then
        end_row = row
        end_column = column
    end

    local code = type(finding.code) == 'string' and finding.code or nil

    return {
        lnum = row - 1,
        end_lnum = end_row - 1,
        col = column - 1,
        end_col = max(end_column - 1, column - 1),
        severity = severity_for(code),
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

    assert(#output <= OUTPUT_BYTES_MAX, 'ruff output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or not vim.islist(decoded) then
        return diagnostics
    end

    for _, finding in ipairs(decoded) do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local item = diagnostic_from_finding(finding)
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
        -- `check` is Ruff's default subcommand; pass it explicitly so the
        -- adapter never depends on that default.
        'check',
        -- JSON is machine-readable; the default `full` format is not.
        '--output-format=json',
        -- Lets Ruff resolve per-file settings as if it read this file.
        '--stdin-filename',
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

    cmd = 'ruff',

    args = args,

    append_fname = false,

    cwd = cwd,

    -- Ruff exits 0 when clean and 1 when it found violations; both are
    -- normal diagnostic-producing outcomes.
    exit_codes = { 0, 1 },

    parser = parse,

    root_markers = {
        'pyproject.toml',
        'ruff.toml',
        '.ruff.toml',
        'setup.cfg',
        'setup.py',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
