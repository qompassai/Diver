-- #################################################################
-- /qompassai/Diver/lua/linters/vale.lua
-- Qompass AI Diver Native Vale Linter
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
---@source https://github.com/errata-ai/vale
---
--- ELI5: Vale is a proofreader for your writing, not your code. It reads the
--- buffer from stdin and checks it against style rules (like "don't use
--- passive voice"). `--output JSON` makes it answer in JSON, `--no-exit`
--- keeps it from exiting nonzero when it finds style issues, and `--ext`
--- tells it the file type (`.md`, `.txt`, ...) so it parses the text
--- correctly. Findings carry a 1-based line and a 1-based character span,
--- a severity word, and the rule name (like `Vale.Spelling`). Vale needs a
--- `.vale.ini` config with styles; without one it reports nothing.
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
local TIMEOUT_MS = 60000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'vale'

local SEVERITIES = {
    error = ERROR,
    hint = HINT,
    information = INFO,
    suggestion = HINT,
    warning = WARN,
}

---@class ValeFinding
---@field Check? string Rule name such as `Vale.Spelling`.
---@field Line? integer 1-based line number.
---@field Message? string Human-readable description.
---@field Severity? string One of error, warning, suggestion, information, hint.
---@field Span? integer[] 1-based [start, end] character offsets.

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

---@param item ValeFinding
---@return vim.Diagnostic.Set?
local function diagnostic_from_finding(item)
    if type(item) ~= 'table' then
        return nil
    end

    local message = clean_message(item.Message)
    local row = integer_in_range(item.Line, 1, 2147483647)
    local severity = SEVERITIES[item.Severity]

    if message == nil or row == nil or severity == nil then
        return nil
    end

    -- Vale spans are 1-based character offsets; treat them as byte offsets.
    -- For non-ASCII text this is approximate, which the runner clamps.
    local span = item.Span
    local start_column = 0
    local end_column = 1
    if span ~= nil and vim.islist(span) and #span >= 2 then
        local span_start = integer_in_range(span[1], 1, 2147483647)
        local span_end = integer_in_range(span[2], 1, 2147483647)
        if span_start ~= nil and span_end ~= nil and span_end >= span_start then
            start_column = span_start - 1
            end_column = span_end
        end
    end

    local check = type(item.Check) == 'string' and item.Check ~= '' and item.Check or nil

    return {
        lnum = row - 1,
        end_lnum = row - 1,
        col = start_column,
        end_col = max(end_column, start_column + 1),
        severity = severity,
        source = SOURCE,
        code = check,
        message = message,
    }
end

---@param context LintContext
---@return string
local function extension(context)
    assert(context.filename ~= '')

    local ext = vim.fn.fnamemodify(context.filename, ':e')
    if ext == '' then
        -- Vale requires an extension to pick a parser; plain text is the
        -- honest fallback.
        return '.txt'
    end

    return '.' .. ext
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    if output == '' then
        return diagnostics
    end

    assert(type(context) == 'table', 'vale parser requires a LintContext')

    ---@cast context LintContext

    assert(#output <= OUTPUT_BYTES_MAX, 'vale output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or type(decoded) ~= 'table' then
        return diagnostics
    end

    -- Vale keys the findings by `stdin` plus the extension it was given.
    local findings = decoded['stdin' .. extension(context)]
    if not vim.islist(findings) then
        return diagnostics
    end

    for _, item in ipairs(findings) do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local diagnostic_item = diagnostic_from_finding(item)
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
        -- Keep the exit code 0 even when findings exist; diagnostics come
        -- from the JSON, not the exit code.
        '--no-exit',
        -- Machine-readable output; the default line format is not parsed.
        '--output',
        'JSON',
        -- Associates the stdin payload with a file type for parsing.
        '--ext',
        extension(context),
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

    cmd = 'vale',

    args = args,

    append_fname = false,

    cwd = cwd,

    parser = parse,

    root_markers = {
        '.vale.ini',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
