-- #################################################################
-- /qompassai/Diver/lua/linters/write_good.lua
-- Qompass AI Diver Native write-good Linter
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
---@source https://github.com/btford/write-good
---
--- ELI5: write-good is a writing coach for English prose. It reads the file
--- from disk (`--parse` makes it print machine-friendly `file:line:column:`
--- lines instead of pretty text) and nags about weasel words ("very",
--- "really"), passive voice, and wordy phrases. Suggestions are hints, not
--- errors — your writing still works, it could just be stronger.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local HINT = diagnostic.severity.HINT

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local type = type

local SOURCE = 'write_good'

-- file:line:column:message
local LINE_PATTERN = '^.-:(%d+):(%d+):(.+)$'

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

    local row, column, message = line:match(LINE_PATTERN)

    if row == nil then
        return nil
    end

    local parsed_row = integer_in_range(row, 1, 2147483647)
    local parsed_column = integer_in_range(column, 0, 2147483647)
    local cleaned = clean_message(message)

    if parsed_row == nil or parsed_column == nil or cleaned == nil then
        return nil
    end

    return {
        lnum = parsed_row - 1,
        end_lnum = parsed_row - 1,
        col = parsed_column,
        end_col = parsed_column + 1,
        severity = HINT,
        source = SOURCE,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'write-good output exceeded maximum size')

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

    cmd = 'write-good',

    -- Machine-readable `file:line:column:` output instead of pretty text.
    args = { '--parse' },

    cwd = cwd,

    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        '.git',
    },

    -- Reads the file from disk, so the runner refuses unsaved buffers.
    stdin = false,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
