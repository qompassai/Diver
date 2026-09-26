-- #################################################################
-- /qompassai/Diver/lua/linters/solhint.lua
-- Qompass AI Diver Native Solhint Solidity Linter
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
---@source https://github.com/protofire/solhint

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN
local INFO = diagnostic.severity.INFO

local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local TIMEOUT_MS = 120000

local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'solhint'

---@class SolhintMessage
---@field line? integer
---@field column? integer
---@field endLine? integer
---@field endColumn? integer
---@field severity? integer|string
---@field ruleId? string
---@field message? string
---@field fatal? boolean

---@class SolhintReport
---@field filePath? string
---@field messages? SolhintMessage[]
---@field errorCount? integer
---@field warningCount? integer

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
    assert(fallback >= 0)

    local parsed = tonumber(value)

    if parsed == nil then
        return fallback
    end

    parsed = math.floor(parsed)

    if parsed < 0 then
        return fallback
    end

    return parsed
end

---@param value string
---@return string
local function trim(value)
    assert(type(value) == 'string')

    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function strip_ansi(value)
    assert(type(value) == 'string')

    return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
    assert(type(value) == 'string')

    value = strip_ansi(value)
    value = value:gsub('\r\n', '\n')
    value = value:gsub('\r', '\n')
    value = trim(value)

    if #value > MESSAGE_LENGTH_MAX then
        value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
    end

    return value
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
    assert(type(path) == 'string')
    assert(path ~= '')
    assert(type(root) == 'string')
    assert(root ~= '')

    if path:sub(1, 7) == 'file://' then
        local ok, filename = pcall(vim.uri_to_fname, path)

        if ok and type(filename) == 'string' and filename ~= '' then
            return fs.normalize(fs.abspath(filename))
        end
    end

    local absolute = vim.fn.isabsolutepath(path) == 1 and path or fs.joinpath(root, path)

    return fs.normalize(fs.abspath(absolute))
end

---@param report SolhintReport
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(report, filename, root)
    assert(type(report) == 'table')
    assert(type(filename) == 'string')
    assert(filename ~= '')
    assert(type(root) == 'string')
    assert(root ~= '')

    if type(report.filePath) ~= 'string' or report.filePath == '' then
        return true
    end

    return normalize_path(report.filePath, root) == filename
end

---@param severity integer|string|nil
---@param fatal boolean|nil
---@return integer
local function diagnostic_severity(severity, fatal)
    if fatal == true then
        return ERROR
    end

    if severity == 2 or severity == 'error' then
        return ERROR
    end

    if severity == 1 or severity == 'warning' or severity == 'warn' then
        return WARN
    end

    return INFO
end

---@param message SolhintMessage
---@return string
local function diagnostic_code(message)
    if type(message.ruleId) == 'string' and message.ruleId ~= '' then
        return message.ruleId
    end

    if message.fatal == true then
        return 'parse'
    end

    return 'solhint'
end

---@param message SolhintMessage
---@return string
local function diagnostic_message(message)
    if type(message.message) ~= 'string' or message.message == '' then
        return 'Solhint reported an unspecified diagnostic'
    end

    return normalize_message(message.message)
end

local function diagnostic_from_message(message)
    assert(type(message) == 'table')

    local line = integer(message.line, 1)
    local column = integer(message.column, 1)
    local end_line = integer(message.endLine, line)
    local end_column = integer(message.endColumn, column + 1)

    local lnum = max(line - 1, 0)
    local col = max(column - 1, 0)
    local end_lnum = max(end_line - 1, lnum)
    local end_col = max(end_column - 1, col + 1)

    if end_lnum == lnum and end_col <= col then
        end_col = col + 1
    end

    return {
        lnum = lnum,
        end_lnum = end_lnum,

        col = col,
        end_col = end_col,

        severity = diagnostic_severity(message.severity, message.fatal),

        source = SOURCE,

        code = diagnostic_code(message),

        message = diagnostic_message(message),

        user_data = {
            analyzer = 'solhint',
            fatal = message.fatal == true,
        },
    }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    assert(type(output) == 'string')
    assert(type(context) == 'table', 'solhint parser requires a LintContext')

    ---@cast context LintContext

    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')
    assert(type(context.root) == 'string')
    assert(context.root ~= '')
    assert(#output <= OUTPUT_LENGTH_MAX, 'solhint output exceeded maximum size')

    local ok, decoded = pcall(vim.json.decode, output)

    if not ok or type(decoded) ~= 'table' then
        local message = normalize_message(output)

        if message == '' then
            return {}
        end

        return {
            {
                lnum = 0,
                end_lnum = 0,
                col = 0,
                end_col = 1,
                severity = ERROR,
                source = SOURCE,
                code = 'invalid-output',
                message = message,
                user_data = {
                    analyzer = 'solhint',
                    location = 'unparsed',
                },
            },
        }
    end

    local filename = fs.normalize(context.filename)
    local root = fs.normalize(context.root)

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for report_index = 1, #decoded do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local report = decoded[report_index]

        if
            type(report) == 'table'
            and belongs_to_buffer(report, filename, root)
            and type(report.messages) == 'table'
        then
            for message_index = 1, #report.messages do
                if #diagnostics >= DIAGNOSTICS_MAX then
                    break
                end

                local message = report.messages[message_index]

                if type(message) == 'table' then
                    diagnostics[#diagnostics + 1] = diagnostic_from_message(message)
                end
            end
        end
    end

    return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')
    assert(type(context.root) == 'string')
    assert(context.root ~= '')

    return {
        '--formatter',
        'json',
        '--disc',
        '--noPoster',
        '--',
        context.filename,
    }
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(type(context.root) == 'string')
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

return ---@type Linter
{
    automatic = true,
    cmd = 'solhint',
    args = args,
    append_fname = false,
    cwd = cwd,
    ignore_exitcode = true,
    parser = parse,
    root_markers = {
        '.solhint.json',
        '.solhintignore',
        'foundry.toml',
        'hardhat.config.js',
        'hardhat.config.cjs',
        'hardhat.config.mjs',
        'hardhat.config.ts',
        'truffle-config.js',
        'truffle.js',
        'package.json',
        '.git',
    },

    stdin = false,
    stream = 'stdout',
    timeout = TIMEOUT_MS,
}
