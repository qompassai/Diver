-- #################################################################
-- /qompassai/lua/linters/mbake.lua
-- Qompass AI Mbake
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
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
        return math.floor(tonumber(value) or fallback)
end

---@param path string
---@param filename string
---@param root string
---@param basename string
---@return boolean
local function belongs_to_buffer(path, filename, root, basename)
        if path == '' then
                return true
        end

        local candidate = fs.is_absolute(path)
                        and fs.normalize(path)
                or fs.normalize(fs.joinpath(root, path))

        return candidate == filename or fs.basename(candidate) == basename
end

---@param message string
---@return string
local function clean_message(message)
        --
        -- mbake may emit:
        --
        --   *** Some validation error. Stop.
        --
        -- Match nvim-lint behavior without performing more work than needed.
        --
        message = message:gsub('^%*+%s*', '', 1)
        message = message:gsub('%s*Stop%.$', '', 1)

        return vim.trim(message)
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if output == '' then
                return {}
        end

        if type(context) ~= 'table' then
                error('mbake parser requires a LintContext', 0)
        end

        ---@cast context LintContext

        local filename = fs.normalize(context.filename)
        local basename = fs.basename(filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}

        --
        -- Expected mbake output:
        --
        --   path/to/file:12: validation message
        --
        for line in output:gmatch('[^\r\n]+') do
                local path, lnum, message =
                        line:match('^%s*(.-):(%d+):%s*(.+)$')

                if
                        path ~= nil
                        and belongs_to_buffer(path, filename, root, basename)
                then
                        local row = math.max(integer(lnum, 1) - 1, 0)

                        diagnostics[#diagnostics + 1] = {
                                lnum = row,
                                end_lnum = row,
                                col = 0,
                                end_col = 1,
                                severity = ERROR,
                                source = 'mbake',
                                message = clean_message(message),
                        }
                end
        end

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'mbake',

        args = {
                'validate',
        },

        append_fname = true,

        cwd = function(context)
                return context.root
        end,

        --
        -- Upstream nvim-lint uses ignore_exitcode = true because mbake
        -- returns failure statuses for validation failures while still
        -- producing useful diagnostics.
        --
        exit_codes = {
                [0] = true,
                [1] = true,
        },

        parser = parse,

        root_markers = {
                'Makefile',
                'makefile',
                'GNUmakefile',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}