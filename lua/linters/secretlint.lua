-- #################################################################
-- /qompassai/lua/linters/secretlint.lua
-- Qompass AI Secretlint
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
-- /qompassai/Diver/lua/linters/secretlint.lua
-- Qompass AI Diver Native Secretlint Linter
-- SPDX-License-Identifier: Apache-2.0
--
-- Secretlint is executed in read-only stdin mode:
--
--     secretlint \
--         --format json \
--         --no-color \
--         --no-terminalLink \
--         --stdinFileName /path/to/file
--
-- The current Neovim buffer is supplied through stdin. Secret values remain
-- masked because `--no-maskSecrets` is intentionally never passed.
-- #################################################################

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

---@class SecretlintLocation
---@field column? integer
---@field line? integer

---@class SecretlintMessage
---@field docsUrl? string
---@field loc? SecretlintLocation|{ start?: SecretlintLocation, ["end"]?: SecretlintLocation }
---@field message? string
---@field messageId? string
---@field ruleId? string
---@field ruleParentId? string
---@field severity? string

---@class SecretlintResult
---@field filePath? string
---@field messages? SecretlintMessage[]
---@field sourceContent? string
---@field sourceContentType? string

---@type table<string, integer>
local severities = {
        error = diagnostic.severity.ERROR,
        hint = diagnostic.severity.HINT,
        info = diagnostic.severity.INFO,
        information = diagnostic.severity.INFO,
        warning = diagnostic.severity.WARN,
        warn = diagnostic.severity.WARN,
}

---@type string[]
local root_markers = {
        '.git',
        '.secretlintignore',
        '.secretlintrc',
        '.secretlintrc.js',
        '.secretlintrc.json',
        '.secretlintrc.yaml',
        '.secretlintrc.yml',
        'package.json',
        'pnpm-lock.yaml',
        'yarn.lock',
}

---Return whether a filesystem path exists.
---@param path string
---@return boolean
local function exists(path)
        return uv.fs_stat(path) ~= nil
end

---Convert an unknown numeric value to an integer.
---@param value unknown
---@param fallback integer
---@return integer
local function integer(value, fallback)
        if type(value) == 'number' then
                return math.floor(value)
        end

        if type(value) == 'string' then
                local parsed = tonumber(value)

                if parsed ~= nil then
                        return math.floor(parsed)
                end
        end

        return fallback
end

---Convert Secretlint severity names to vim.diagnostic severity values.
---@param value unknown
---@return integer
local function severity(value)
        local name = tostring(value or ''):lower()

        return severities[name] or diagnostic.severity.ERROR
end

---Resolve the starting location from a Secretlint message.
---
---Secretlint's internal result structure uses a `loc` object. This helper
---accepts both a direct line/column object and a start/end location structure
---so the parser remains tolerant across formatter/schema revisions.
---
---@param message SecretlintMessage
---@return integer, integer
local function start_location(message)
        local location = message.loc

        if type(location) ~= 'table' then
                return 0, 0
        end

        local start = location.start

        if type(start) == 'table' then
                return math.max(integer(start.line, 1) - 1, 0),
                        math.max(integer(start.column, 1) - 1, 0)
        end

        return math.max(integer(location.line, 1) - 1, 0),
                math.max(integer(location.column, 1) - 1, 0)
end

---Resolve the ending location from a Secretlint message.
---@param message SecretlintMessage
---@param lnum integer
---@param col integer
---@return integer, integer
local function end_location(message, lnum, col)
        local location = message.loc

        if type(location) ~= 'table' then
                return lnum, col + 1
        end

        local finish = location['end']

        if type(finish) ~= 'table' then
                return lnum, col + 1
        end

        local end_lnum = math.max(
                integer(finish.line, lnum + 1) - 1,
                lnum
        )

        local end_col = math.max(
                integer(finish.column, col + 2) - 1,
                0
        )

        if end_lnum == lnum then
                end_col = math.max(end_col, col + 1)
        end

        return end_lnum, end_col
end

---Build a concise diagnostic code from Secretlint message metadata.
---
---The message ID is generally the most useful identifier to expose through
---vim.diagnostic. If it is unavailable, fall back to the rule identifier.
---
---@param message SecretlintMessage
---@return string?
local function diagnostic_code(message)
        if
                type(message.messageId) == 'string'
                and message.messageId ~= ''
        then
                return message.messageId
        end

        if
                type(message.ruleId) == 'string'
                and message.ruleId ~= ''
        then
                return message.ruleId
        end

        return nil
end

---Build the diagnostic source label.
---
---Nested preset rules retain both the parent preset and concrete rule in
---user_data, while the visible source remains simply `secretlint`.
---
---@return string
local function diagnostic_source()
        return 'secretlint'
end

---Normalize Secretlint JSON formatter output into a result array.
---
---The parser accepts either:
---
---    [ { filePath = ..., messages = ... } ]
---
---or a single result object. This keeps the native integration tolerant of
---minor formatter changes without weakening validation of individual records.
---
---@param decoded unknown
---@return SecretlintResult[]
local function results(decoded)
        if type(decoded) ~= 'table' then
                return {}
        end

        if decoded.messages ~= nil or decoded.filePath ~= nil then
                ---@cast decoded SecretlintResult
                return {
                        decoded,
                }
        end

        ---@cast decoded SecretlintResult[]
        return decoded
end

---Parse Secretlint JSON output into native Neovim diagnostics.
---
---Secretlint masks detected secret values by default. The linter deliberately
---does not pass `--no-maskSecrets`, preventing credentials from being exposed
---in Neovim diagnostics or logs.
---
---@param output string
---@param _context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
        if vim.trim(output) == '' then
                return {}
        end

        local ok, decoded = pcall(
                vim.json.decode,
                output
        )

        if not ok then
                error(
                        ('invalid secretlint JSON: %s'):format(
                                vim.trim(output)
                        ),
                        0
                )
        end

        local diagnostics = {}

        for _, result in ipairs(results(decoded)) do
                if
                        type(result) == 'table'
                        and type(result.messages) == 'table'
                then
                        for _, message in ipairs(result.messages) do
                                if type(message) == 'table' then
                                        local lnum, col =
                                                start_location(message)

                                        local end_lnum, end_col =
                                                end_location(
                                                        message,
                                                        lnum,
                                                        col
                                                )

                                        local code =
                                                diagnostic_code(message)

                                        local text = tostring(
                                                message.message
                                                        or 'Secret detected'
                                        )

                                        diagnostics[#diagnostics + 1] = {
                                                code = code,
                                                col = col,
                                                end_col = end_col,
                                                end_lnum = end_lnum,
                                                lnum = lnum,
                                                message = code ~= nil
                                                                and ('[%s] %s'):format(
                                                                        code,
                                                                        text
                                                                )
                                                        or text,
                                                severity = severity(
                                                        message.severity
                                                ),
                                                source = diagnostic_source(),
                                                user_data = {
                                                        docs_url =
                                                                message.docsUrl,
                                                        file =
                                                                result.filePath,
                                                        message_id =
                                                                message.messageId,
                                                        rule =
                                                                message.ruleId,
                                                        rule_parent =
                                                                message.ruleParentId,
                                                },
                                        }
                                end
                        end
                end
        end

        return diagnostics
end

---Resolve the Secretlint executable.
---
---Preference:
---
---1. Project-local node_modules/.bin/secretlint
---2. Globally installed/single-binary secretlint
---
---Using a project-local executable first ensures that its rules and Secretlint
---version correspond to the project's package manifest and lockfile.
---
---@param context LintContext
---@return string
local function command(context)
        local local_command = fs.joinpath(
                context.root,
                'node_modules',
                '.bin',
                'secretlint'
        )

        if exists(local_command) then
                return local_command
        end

        return 'secretlint'
end

---Build Secretlint arguments for the current buffer.
---
---`--format=json`
---    Produces machine-readable output for the native diagnostic parser.
---
---`--no-color`
---    Prevents ANSI escape sequences from contaminating JSON output.
---
---`--no-terminalLink`
---    Prevents terminal hyperlink escape sequences in editor output.
---
---`--stdinFileName`
---    Supplies the real buffer filename while content itself arrives through
---    stdin. Some Secretlint rules depend on the filename to decide whether a
---    rule applies.
---
---Secret masking remains enabled by default for security.
---
---@param context LintContext
---@return string[]
local function args(context)
        return {
                '--format=json',
                '--no-color',
                '--no-terminalLink',
                '--stdinFileName=' .. context.filename,
        }
end

---Run Secretlint from the project root.
---
---This permits normal discovery of:
---
---    .secretlintrc.*
---    .secretlintignore
---    .gitignore
---    project-local rule packages
---
---@param context LintContext
---@return string
local function cwd(context)
        return context.root
end

return ---@type Linter
{
        append_fname = false,

        args = args,

        cmd = command,

        cwd = cwd,

        -- 0: no secrets were reported.
        -- 1: lint findings were reported.
        --
        -- Exit code 2 is intentionally not accepted because Secretlint
        -- documents it as an unexpected/fatal execution error.
        exit_codes = {
                [0] = true,
                [1] = true,
        },

        parser = parse,

        root_markers = root_markers,

        -- Current unsaved buffer contents are scanned rather than requiring
        -- Neovim to write potentially sensitive content to disk first.
        stdin = true,

        -- JSON formatter output is emitted on stdout.
        stream = 'stdout',

        timeout = 30000,
}