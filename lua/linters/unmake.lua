-- #################################################################
-- /qompassai/lua/linters/unmake.lua
-- Qompass AI Unmake
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
-- /qompassai/Diver/lua/linters/unmake.lua
-- Qompass AI Diver Native Unmake Linter
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic

local severities = {
        error = diagnostic.severity.ERROR,
        hint = diagnostic.severity.HINT,
        info = diagnostic.severity.INFO,
        information = diagnostic.severity.INFO,
        warning = diagnostic.severity.WARN,
        warn = diagnostic.severity.WARN,
}

local root_markers = {
        '.git',
        'GNUmakefile',
        'Makefile',
        'makefile',
}

---@param value any
---@param fallback integer
---@return integer
local function integer(value, fallback)
        local parsed = tonumber(value)

        if parsed == nil then
                return fallback
        end

        return math.floor(parsed)
end

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
        local diagnostics = {}

        for line in vim.gsplit(output, '\n', {
                plain = true,
                trimempty = true,
        }) do
                local severity,
                        filename,
                        lnum,
                        column,
                        message = line:match(
                                '^([%w_%-]+):%s+(.-):(%d*):?(%d*):%s+(.+)$'
                        )

                if
                        severity ~= nil
                        and filename ~= nil
                        and message ~= nil
                then
                        local level = severity:lower()
                        local line_number = math.max(integer(lnum, 1) - 1, 0)
                        local start_column = math.max(integer(column, 1) - 1, 0)

                        diagnostics[#diagnostics + 1] = {
                                col = start_column,
                                end_col = start_column + 1,
                                end_lnum = line_number,
                                lnum = line_number,
                                message = vim.trim(message),
                                severity = severities[level]
                                        or diagnostic.severity.WARN,
                                source = 'unmake',
                                user_data = {
                                        filename = filename,
                                },
                        }
                end
        end

        return diagnostics
end

---@param context LintContext
---@return string
local function cwd(context)
        return context.root
end

return ---@type Linter
{
        append_fname = false,
        args = {},
        cmd = 'unmake',
        cwd = cwd,
        exit_codes = {
                [0] = true,
                [1] = true,
        },
        parser = parse,
        root_markers = root_markers,
        stdin = false,
        stream = 'stdout',
        timeout = 60000,
}