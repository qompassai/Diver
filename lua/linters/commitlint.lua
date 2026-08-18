-- #################################################################
-- /qompassai/lua/linters/commitlint.lua
-- Qompass AI Commitlint
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

local diagnostic = vim.diagnostic

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 256
local LINE_LENGTH_MAX = 8192

---@type table<string, integer>
local severities = {
        ['1'] = WARN,
        ['2'] = ERROR,
}

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
        assert(fallback >= 0)

        local parsed = tonumber(value)
        if parsed == nil then
                return fallback
        end

        return math.floor(parsed)
end

---@param line string
---@return integer?, string?, string?
local function parse_line(line)
        assert(#line <= LINE_LENGTH_MAX)

        --
        -- commitlint default output commonly contains rule lines such as:
        --
        --   ✖   subject may not be empty [subject-empty]
        --   ⚠   body must have leading blank line [body-leading-blank]
        --
        -- Some formatters also prefix numeric severity. Accept both forms
        -- without coupling the linter to terminal decoration.
        --

        local symbol
        local message
        local rule

        symbol, message, rule =
                line:match('^%s*([✖⚠])%s+(.+)%s+%[([^%]]+)%]%s*$')

        if symbol ~= nil then
                local level = symbol == '✖' and ERROR or WARN
                return level, message, rule
        end

        local numeric

        numeric, message, rule =
                line:match('^%s*([12])%s+(.+)%s+%[([^%]]+)%]%s*$')

        if numeric ~= nil then
                return severities[numeric], message, rule
        end

        return nil
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if output == '' then
                return {}
        end

        assert(
                type(context) == 'table',
                'commitlint parser requires a LintContext'
        )

        ---@cast context LintContext

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                if #line <= LINE_LENGTH_MAX then
                        local level
                        local message
                        local rule

                        level, message, rule = parse_line(line)

                        if
                                level ~= nil
                                and message ~= nil
                                and rule ~= nil
                        then
                                diagnostics_count = diagnostics_count + 1

                                diagnostics[diagnostics_count] = {
                                        lnum = 0,
                                        end_lnum = 0,
                                        col = 0,
                                        end_col = 1,
                                        message = message,
                                        severity = level,
                                        source = 'commitlint',
                                        code = rule,
                                }
                        end
                end
        end

        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'commitlint',

        args = {
                '--color=false',
        },

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')
                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                '.commitlintrc',
                '.commitlintrc.json',
                '.commitlintrc.yaml',
                '.commitlintrc.yml',
                '.commitlintrc.js',
                '.commitlintrc.cjs',
                '.commitlintrc.mjs',
                '.commitlintrc.ts',
                '.commitlintrc.cts',
                '.commitlintrc.mts',
                'commitlint.config.js',
                'commitlint.config.cjs',
                'commitlint.config.mjs',
                'commitlint.config.ts',
                'commitlint.config.cts',
                'commitlint.config.mts',
                'package.json',
                '.git',
        },

        stdin = true,
        stream = 'stdout',
        timeout = 30000,
}