-- #################################################################
-- /qompassai/Diver/lua/linters/eslint_d.lua
-- Qompass AI Diver Native ESLint_D Tiger Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/mantoni/eslint_d.js
---@source https://eslint.org/docs/latest/use/command-line-interface/
---@source https://eslint.org/docs/latest/use/formatters/
local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json
local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN
local DIAGNOSTICS_MAX = 4096
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local floor = math.floor
local max = math.max
local min = math.min
local tonumber = tonumber
local type = type
local SOURCE = 'eslint_d'
---@type table<integer, integer>
local SEVERITIES = {
    [1] = WARN,
    [2] = ERROR,
}
---@class EslintDFix
---@field range? integer[]
---@field text? string
---@class EslintDSuggestion
---@field desc? string
---@field messageId? string
---@field fix? EslintDFix
---@class EslintDMessage
---@field ruleId? string
---@field severity? integer
---@field fatal? boolean
---@field message? string
---@field messageId? string
---@field line? integer
---@field column? integer
---@field endLine? integer
---@field endColumn? integer
---@field nodeType? string
---@field fix? EslintDFix
---@field suggestions? EslintDSuggestion[]

---@class EslintDResult
---@field filePath? string
---@field messages? EslintDMessage[]
---@field suppressedMessages? EslintDMessage[]
---@field errorCount? integer
---@field fatalErrorCount? integer
---@field warningCount? integer
---@field fixableErrorCount? integer
---@field fixableWarningCount? integer

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
    assert(fallback >= 0, 'fallback must be non-negative')
    local parsed = tonumber(value)

    if parsed == nil then
        return fallback
    end

    return floor(parsed)
end

---@param value string
---@return string
local function trim(value)
    assert(type(value) == 'string', 'value must be a string')

    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function normalize_message(value)
    assert(type(value) == 'string', 'value must be a string')

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
    assert(path ~= '', 'path must not be empty')

    assert(root ~= '', 'root must not be empty')

    if path:sub(1, 7) == 'file://' then
        local ok, filename = pcall(vim.uri_to_fname, path)

        if ok and type(filename) == 'string' and filename ~= '' then
            return fs.normalize(filename)
        end
    end

    if path:sub(1, 1) == '/' then
        return fs.normalize(path)
    end

    return fs.normalize(fs.joinpath(root, path))
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(candidate, filename, root)
    assert(candidate ~= '', 'candidate must not be empty')
    assert(filename ~= '', 'filename must not be empty')
    assert(root ~= '', 'root must not be empty')

    return normalize_path(candidate, root) == normalize_path(filename, root)
end

---@param value integer|nil
---@param fatal boolean|nil
---@return integer
local function severity(value, fatal)
    if fatal == true then
        return ERROR
    end

    if type(value) ~= 'number' then
        return ERROR
    end

    return SEVERITIES[floor(value)] or ERROR
end

---@param entry EslintDMessage
---@return string?
local function diagnostic_code(entry)
    if type(entry.ruleId) == 'string' and entry.ruleId ~= '' then
        return entry.ruleId
    end

    if entry.fatal == true then
        return 'fatal'
    end

    if type(entry.messageId) == 'string' and entry.messageId ~= '' then
        return entry.messageId
    end

    return nil
end

---@param entry EslintDMessage
---@param bufnr integer
---@return vim.Diagnostic?
local function diagnostic_from_message(entry, bufnr)
    local message = entry.message

    if type(message) ~= 'string' or message == '' then
        return nil
    end

    message = normalize_message(message)

    if message == '' then
        return nil
    end

    local start_line = max(integer(entry.line, 1), 1)
    local start_column = max(integer(entry.column, 1), 1)

    local lnum = start_line - 1

    local col = start_column - 1

    local end_line = max(integer(entry.endLine, start_line), start_line)

    local end_lnum = end_line - 1

    local minimum_end_column = end_lnum == lnum and start_column + 1 or 1

    local reported_end_column = max(integer(entry.endColumn, minimum_end_column), minimum_end_column)

    local end_col = max(reported_end_column - 1, end_lnum == lnum and col + 1 or 0)

    local code = diagnostic_code(entry)

    local suggestions = entry.suggestions
    local suggestion_count = 0

    if type(suggestions) == 'table' then
        suggestion_count = #suggestions
    end

    return {
        bufnr = bufnr,

        lnum = lnum,
        end_lnum = end_lnum,

        col = col,
        end_col = end_col,

        message = message,

        severity = severity(entry.severity, entry.fatal),

        source = SOURCE,
        code = code,

        user_data = {
            fatal = entry.fatal == true,
            fixable = type(entry.fix) == 'table',
            message_id = entry.messageId,
            node_type = entry.nodeType,
            rule_id = entry.ruleId,
            suggestion_count = suggestion_count,
        },
    }
end

---@param result EslintDResult
---@param context LintContext
---@param filename string
---@param root string
---@param diagnostics vim.Diagnostic.Set[]
local function parse_result(result, context, filename, root, diagnostics)
    local result_file = result.filePath

    if type(result_file) == 'string' and result_file ~= '' and not belongs_to_buffer(result_file, filename, root) then
        return
    end

    local messages = result.messages

    if type(messages) ~= 'table' then
        return
    end

    local available = DIAGNOSTICS_MAX - #diagnostics

    local count = min(#messages, available)

    for index = 1, count do
        local raw = messages[index]

        if type(raw) == 'table' then
            ---@cast raw EslintDMessage

            local entry = diagnostic_from_message(raw, context.bufnr)

            if entry ~= nil then
                diagnostics[#diagnostics + 1] = entry
            end
        end
    end
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    assert(type(context) == 'table', 'eslint_d parser requires a LintContext')

    ---@cast context LintContext

    assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

    assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

    assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

    assert(#output <= OUTPUT_LENGTH_MAX, 'eslint_d output exceeded maximum size')

    local ok, decoded = pcall(json.decode, output)

    if not ok or type(decoded) ~= 'table' then
        return {}
    end

    local filename = normalize_path(context.filename, context.root)

    local root = fs.normalize(context.root)

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for index = 1, #decoded do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local raw = decoded[index]

        if type(raw) == 'table' then
            ---@cast raw EslintDResult

            parse_result(raw, context, filename, root, diagnostics)
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX, 'diagnostic limit exceeded')

    return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
    assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

    return {
        '--stdin',

        '--stdin-filename',
        context.filename,
        '--format',
        'json',
        '--no-color',
        '--report-unused-disable-directives-severity',
        'error',
        '--report-unused-inline-configs',
        'error',
        '--no-warn-ignored',
        '--max-warnings',
        '0',
    }
end
---@param context LintContext
---@return string
local function cwd(context)
    assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

    return fs.normalize(context.root)
end

return ---@type Linter
{
    automatic = false,
    cmd = 'eslint_d',
    args = args,
    append_fname = false,
    cwd = cwd,
    ignore_exitcode = true,
    parser = parse,
    root_markers = {
        'eslint.config.js',
        'eslint.config.mjs',
        'eslint.config.cjs',
        'eslint.config.ts',
        'eslint.config.mts',
        'eslint.config.cts',
        '.eslintrc',
        '.eslintrc.js',
        '.eslintrc.cjs',
        '.eslintrc.json',
        '.eslintrc.yaml',
        '.eslintrc.yml',
        'package.json',
        'pnpm-workspace.yaml',
        'pnpm-lock.yaml',
        'package-lock.json',
        'yarn.lock',
        'bun.lock',
        'bun.lockb',

        '.git',
    },
    stdin = true,
    stream = 'stdout',
    timeout = 30000,
}
