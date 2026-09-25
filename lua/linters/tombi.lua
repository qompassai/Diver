-- #################################################################
-- /qompassai/Diver/lua/linters/tombi.lua
-- Qompass AI Diver Native Tombi Linter
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
---@source https://github.com/tombi-toml/tombi
---
--- ELI5: Tombi is a toolkit for TOML files (the config files that look like
--- `key = "value"`). `tombi lint` checks your TOML for syntax mistakes and
--- style problems. It reads the buffer from stdin (the `-` at the end, with
--- `--stdin-filename` telling it which file the piped text pretends to be
--- so schema-aware rules apply), and it reports problems on stderr as a
--- message line followed by a location line:
---
---     Error: expected ']'
---       at file.toml:2:1
---
--- The location's line and column are 1-based.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 1024
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'tombi'

local SEVERITIES = {
    Error = ERROR,
    Warning = WARN,
}

-- `  Error: expected ']'` / `  Warning: ...`
local MESSAGE_PATTERN = '^%s*(Error|Warning):%s*(.+)$'
-- `    at file.toml:2:1`
local LOCATION_PATTERN = '^%s*at%s+.+:(%d+):(%d+)%s*$'

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

---@param output string
---@param _ LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    if output == '' then
        return diagnostics
    end

    assert(#output <= OUTPUT_BYTES_MAX, 'tombi output exceeded maximum size')

    ---@type integer?
    local severity = nil
    ---@type string?
    local message = nil

    for line in output:gmatch('[^\r\n]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        if #line <= LINE_LENGTH_MAX then
            local kind, text = line:match(MESSAGE_PATTERN)
            if kind ~= nil then
                severity = SEVERITIES[kind]
                message = clean_message(text)
            else
                local row, column = line:match(LOCATION_PATTERN)
                if row ~= nil and severity ~= nil and message ~= nil then
                    local parsed_row = integer_in_range(row, 1, 2147483647)
                    local parsed_column = integer_in_range(column, 1, 2147483647)

                    if parsed_row ~= nil and parsed_column ~= nil then
                        diagnostics[#diagnostics + 1] = {
                            lnum = parsed_row - 1,
                            end_lnum = parsed_row - 1,
                            col = max(parsed_column - 1, 0),
                            end_col = parsed_column,
                            severity = severity,
                            source = SOURCE,
                            message = message,
                        }
                    end

                    severity = nil
                    message = nil
                end
            end
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
        'lint',
        -- Filename to associate with the stdin payload for schema-aware rules.
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

    cmd = 'tombi',

    args = args,

    append_fname = false,

    cwd = cwd,

    -- Tombi exits 0 when clean and 1 when it found problems.
    exit_codes = { 0, 1 },

    parser = parse,

    root_markers = {
        'tombi.toml',
        '.tombi.toml',
        'pyproject.toml',
        '.git',
    },

    stdin = true,

    -- Tombi reports diagnostics on stderr (verified against v1.5.5).
    stream = 'stderr',

    timeout = TIMEOUT_MS,
}
