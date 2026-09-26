-- #################################################################
-- /qompassai/Diver/lua/linters/zizmor.lua
-- Qompass AI Diver Native Zizmor Linter
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
---@source https://github.com/zizmorcore/zizmor
---
--- ELI5: zizmor is a security checker for GitHub Actions workflow files
--- (the YAML under `.github/workflows/`). It reads your file from stdin
--- (the `-` at the end) and answers in the same `::warning`/`::error`
--- annotations that GitHub itself uses (`--format github`):
---
---     ::warning file=-,line=5,endLine=5,col=1,endColumn=1,title=...::message
---
--- The `file=-` part means "the thing I piped in", i.e. your buffer.
--- `--no-progress` and `--no-exit-codes` keep it quiet and simple, and the
--- finding's title becomes the diagnostic code. This check walks the whole
--- workflow, so it only runs when you ask for it, not on every save.
---

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 1024
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_BYTES_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 60000

local floor = math.floor
local max = math.max
local type = type

local SOURCE = 'zizmor'

local SEVERITIES = {
    error = ERROR,
    warning = WARN,
}

-- ::warning file=-,line=5,endLine=5,col=1,endColumn=1,title=...::message
local ANNOTATION_PATTERN = '^::(%w+)%s+([^:]*)::(.*)$'

---@param value string?
---@param minimum integer
---@param maximum integer
---@param fallback integer
---@return integer
local function integer_or_fallback(value, minimum, maximum, fallback)
    assert(minimum >= 0)
    assert(maximum >= minimum)
    assert(fallback >= minimum and fallback <= maximum)

    local parsed = value ~= nil and tonumber(value) or nil

    if parsed == nil or parsed ~= floor(parsed) or parsed < minimum or parsed > maximum then
        return fallback
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

    local kind, properties, message = line:match(ANNOTATION_PATTERN)

    if kind == nil or SEVERITIES[kind] == nil then
        return nil
    end

    local cleaned = clean_message(message)
    if cleaned == nil then
        return nil
    end

    ---@type table<string, string>
    local props = {}
    for key, value in properties:gmatch('(%w+)=([^,]+)') do
        props[key] = value
    end

    local row = integer_or_fallback(props.line, 1, 2147483647, 1)
    local end_row = integer_or_fallback(props.endLine, 1, 2147483647, row)
    local column = integer_or_fallback(props.col, 1, 2147483647, 1)
    local end_column = integer_or_fallback(props.endColumn, 1, 2147483647, column)

    if end_row < row or (end_row == row and end_column < column) then
        end_row = row
        end_column = column
    end

    local title = props.title
    local code = title ~= nil and title ~= '' and title or nil

    return {
        lnum = row - 1,
        end_lnum = end_row - 1,
        col = max(column - 1, 0),
        end_col = max(end_column - 1, 0),
        severity = SEVERITIES[kind],
        source = SOURCE,
        code = code,
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

    assert(#output <= OUTPUT_BYTES_MAX, 'zizmor output exceeded maximum size')

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
    -- Security analysis is slow and project-wide; it runs on demand.
    automatic = false,

    cmd = 'zizmor',

    args = {
        -- GitHub workflow-annotation output; easy to parse line by line.
        '--format',
        'github',
        -- Keep the output free of progress noise.
        '--no-progress',
        -- Exit 0 regardless of findings; diagnostics come from the output.
        '--no-exit-codes',
        -- Read the buffer from stdin.
        '-',
    },

    append_fname = false,

    cwd = cwd,

    exit_codes = { 0 },

    parser = parse,

    root_markers = {
        '.github',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
