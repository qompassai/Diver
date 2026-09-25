-- #################################################################
-- /qompassai/Diver/lua/linters/eslint.lua
-- Qompass AI Diver Native ESLint Linter
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
---@source https://github.com/eslint/eslint
---
--- ELI5: ESLint is the rule-enforcer for JavaScript and TypeScript. It reads
--- your file from stdin (`--stdin`, with `--stdin-filename` telling it which
--- file the piped code pretends to be so it finds the right config) and
--- answers in JSON (`--format json`): one result per file, each with a list
--- of messages carrying the rule id, a 1-or-2 severity, and line/column
--- ranges. Severity 2 means error, 1 means warning. If ESLint has no config
--- for the file it says so instead of producing diagnostics, and this
--- adapter stays quiet in that case.
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

local SOURCE = 'eslint'

---@class EslintMessage
---@field column? integer 1-based column.
---@field endColumn? integer 1-based end column.
---@field endLine? integer 1-based end line.
---@field line? integer 1-based line.
---@field message? string Human-readable description.
---@field ruleId? string Rule id such as `no-unused-vars`.
---@field severity? integer 1 for warning, 2 for error.

---@class EslintResult
---@field filePath? string
---@field messages? EslintMessage[]

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

---@param message EslintMessage
---@param diagnostics vim.Diagnostic.Set[]
local function append_message(message, diagnostics)
    if type(message) ~= 'table' then
        return
    end

    local text = clean_message(message.message)
    if text == nil then
        return
    end

    local row = integer_in_range(message.line, 1, 2147483647) or 1
    local column = integer_in_range(message.column, 1, 2147483647) or 1
    local end_row = integer_in_range(message.endLine, 1, 2147483647)
    local end_column = integer_in_range(message.endColumn, 1, 2147483647)
    local severity = message.severity == 2 and ERROR or WARN
    local rule = type(message.ruleId) == 'string' and message.ruleId or nil

    if end_row ~= nil and end_column ~= nil then
        if end_row < row or (end_row == row and end_column < column) then
            end_row = nil
            end_column = nil
        end
    end

    diagnostics[#diagnostics + 1] = {
        lnum = row - 1,
        end_lnum = end_row ~= nil and (end_row - 1) or (row - 1),
        col = max(column - 1, 0),
        end_col = end_column ~= nil and max(end_column - 1, 0) or nil,
        severity = severity,
        source = SOURCE,
        code = rule,
        message = text,
    }
end

---@param output string
---@param _ LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _)
    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    local trimmed = vim.trim(output)
    if trimmed == '' then
        return diagnostics
    end

    -- No config for this file: ESLint explains itself on stdout; that is a
    -- setup problem, not a buffer diagnostic.
    if trimmed:find('No ESLint configuration found', 1, true) ~= nil then
        return diagnostics
    end

    assert(#output <= OUTPUT_BYTES_MAX, 'eslint output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)
    if not ok or not vim.islist(decoded) then
        return diagnostics
    end

    for _, result in ipairs(decoded) do
        if type(result) == 'table' and vim.islist(result.messages) then
            for _, message in ipairs(result.messages) do
                if #diagnostics >= DIAGNOSTICS_MAX then
                    break
                end
                append_message(message, diagnostics)
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
---@return string[]
local function args(context)
    assert(context.filename ~= '')

    return {
        -- Machine-readable output; the default `stylish` format is not parsed.
        '--format',
        'json',
        -- Read the buffer from stdin.
        '--stdin',
        -- Lets ESLint resolve config as if it read this file.
        '--stdin-filename',
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

    cmd = 'eslint',

    args = args,

    append_fname = false,

    cwd = cwd,

    -- ESLint exits 0 when clean, 1 when it found problems, 2 on config
    -- errors. A config error must stay visible, so only 0 and 1 pass.
    exit_codes = { 0, 1 },

    parser = parse,

    root_markers = {
        'eslint.config.js',
        'eslint.config.mjs',
        'eslint.config.cjs',
        'eslint.config.ts',
        '.eslintrc',
        '.eslintrc.js',
        '.eslintrc.json',
        'package.json',
        '.git',
    },

    stdin = true,

    stream = 'stdout',

    timeout = TIMEOUT_MS,
}
