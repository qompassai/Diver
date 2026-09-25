-- #################################################################
-- /qompassai/Diver/lua/linters/deno.lua
-- Qompass AI Diver Native Deno Linter
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
---@source https://github.com/denoland/deno
---
--- ELI5: Deno is a JavaScript/TypeScript runtime that ships its own linter.
--- `deno lint --json` checks the file on disk and answers in JSON with two
--- lists: `diagnostics` (lint findings, shown as warnings) and `errors`
--- (things that stopped the check, shown as errors). Positions are 1-based
--- lines with 0-based columns, verified against the real tool. It cannot
--- read from stdin, so write the buffer first.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 16 * 1024 * 1024
local TIMEOUT_MS = 60000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'deno'

---@class DenoPosition
---@field line? integer 1-based line.
---@field col? integer 0-based column.

---@class DenoDiagnostic
---@field code? string Rule code such as `no-unused-vars`.
---@field filename? string
---@field hint? string Extra advice shown after the message.
---@field message? string Human-readable description.
---@field range? { start?: DenoPosition, end?: DenoPosition }

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

---@param position any
---@return integer row 0-based line.
---@return integer column 0-based column.
local function parse_position(position)
    local row = 0
    local column = 0

    if type(position) == 'table' then
        -- Deno reports 1-based lines and 0-based columns.
        row = integer_in_range(position.line, 1, 2147483647) or 1
        row = row - 1
        column = integer_in_range(position.col, 0, 2147483647) or 0
    end

    return row, column
end

---@param item DenoDiagnostic
---@param severity integer
---@return vim.Diagnostic.Set?
local function diagnostic_from_item(item, severity)
    if type(item) ~= 'table' then
        return nil
    end

    local message = clean_message(item.message)
    if message == nil then
        return nil
    end

    local hint = clean_message(item.hint)
    if hint ~= nil then
        message = message .. ' Hint: ' .. hint
    end

    local range = item.range
    local start_row, start_column = parse_position(type(range) == 'table' and range.start or nil)
    local end_row, end_column = parse_position(type(range) == 'table' and range['end'] or nil)

    if end_row < start_row or (end_row == start_row and end_column < start_column) then
        end_row = start_row
        end_column = start_column
    end

    local code = type(item.code) == 'string' and item.code ~= '' and item.code or nil

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

---@param decoded table
---@param key string
---@param severity integer
---@param diagnostics vim.Diagnostic.Set[]
local function append_group(decoded, key, severity, diagnostics)
    local group = decoded[key]
    if not vim.islist(group) then
        return
    end

    for _, item in ipairs(group) do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local diagnostic_item = diagnostic_from_item(item, severity)
        if diagnostic_item ~= nil then
            diagnostics[#diagnostics + 1] = diagnostic_item
        end
    end
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

    assert(#output <= OUTPUT_BYTES_MAX, 'deno output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or type(decoded) ~= 'table' then
        return diagnostics
    end

    append_group(decoded, 'diagnostics', WARN, diagnostics)
    append_group(decoded, 'errors', ERROR, diagnostics)

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

    cmd = 'deno',

    -- Machine-readable output; the default human format is not parsed.
    args = { 'lint', '--json' },

    cwd = cwd,

    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        'deno.json',
        'deno.jsonc',
        '.git',
    },

    -- Reads the file from disk, so the runner refuses unsaved buffers.
    stdin = false,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
