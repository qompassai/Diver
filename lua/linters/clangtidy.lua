-- #################################################################
-- /qompassai/lua/linters/clangtidy.lua
-- Qompass AI Clang-Tidy
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
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN
local INFO = diagnostic.severity.INFO
local HINT = diagnostic.severity.HINT

---@type table<string, string|false>
local compilation_database_cache = {}

---@type table<string, integer>
local severities = {
        ['error'] = ERROR,
        ['fatal error'] = ERROR,
        ['warning'] = WARN,
        ['warn'] = WARN,
        ['information'] = INFO,
        ['info'] = INFO,
        ['note'] = HINT,
        ['hint'] = HINT,
}

---@param value string|number|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
        return math.floor(tonumber(value) or fallback)
end

---@param value string|nil
---@return integer
local function severity(value)
        if value == nil then
                return WARN
        end

        return severities[value:lower()] or WARN
end

---@param path string
---@return boolean
local function is_file(path)
        local stat = uv.fs_stat(path)
        return stat ~= nil and stat.type == 'file'
end

---@param root string
---@return string?
local function compilation_database(root)
        local cached = compilation_database_cache[root]

        if cached ~= nil then
                return cached ~= false and cached or nil
        end

        --
        -- Prefer the project root first because some generators symlink or
        -- copy compile_commands.json there.
        --
        local candidates = {
                root,
                fs.joinpath(root, 'build'),
                fs.joinpath(root, 'build-debug'),
                fs.joinpath(root, 'build-release'),
                fs.joinpath(root, 'cmake-build-debug'),
                fs.joinpath(root, 'cmake-build-release'),
                fs.joinpath(root, 'out'),
        }

        for _, directory in ipairs(candidates) do
                if is_file(fs.joinpath(directory, 'compile_commands.json')) then
                        compilation_database_cache[root] = directory
                        return directory
                end
        end

        compilation_database_cache[root] = false
        return nil
end

---@param path string
---@param normalized_filename string
---@param root string
---@param basename string
---@return boolean
local function belongs_to_buffer(path, normalized_filename, root, basename)
        if path == '' then
                return true
        end

        local candidate

        if fs.is_absolute(path) then
                candidate = fs.normalize(path)
        else
                candidate = fs.normalize(fs.joinpath(root, path))
        end

        if candidate == normalized_filename then
                return true
        end

        --
        -- clang-tidy can occasionally print a path in a representation that
        -- differs from the path Neovim has for the buffer. Basename matching
        -- provides a conservative fallback.
        --
        return fs.basename(candidate) == basename
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if output == '' then
                return {}
        end

        if type(context) ~= 'table' then
                error('clang-tidy parser requires a LintContext', 0)
        end

        ---@cast context LintContext

        local filename = fs.normalize(context.filename)
        local basename = fs.basename(filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}

        --
        -- Match only actual clang diagnostics:
        --
        --   foo.cpp:12:4: warning: diagnostic text [check-name]
        --
        -- Non-diagnostic lines such as source snippets, carets and suppression
        -- summaries are ignored without raising errors.
        --
        for line in output:gmatch('[^\r\n]+') do
                local path, lnum, col, level, message =
                        line:match('^(.-):(%d+):(%d+):%s*([^:]+):%s*(.+)$')

                if path ~= nil then
                        local text, code =
                                message:match('^(.-)%s+%[([^%]]+)%]%s*$')

                        text = text or message

                        if belongs_to_buffer(
                                path,
                                filename,
                                root,
                                basename
                        ) then
                                local row = math.max(integer(lnum, 1) - 1, 0)
                                local column = math.max(integer(col, 1) - 1, 0)

                                diagnostics[#diagnostics + 1] = {
                                        lnum = row,
                                        end_lnum = row,
                                        col = column,
                                        end_col = column + 1,
                                        message = text,
                                        severity = severity(level),
                                        source = 'clang-tidy',
                                        code = code,
                                }
                        end
                end
        end

        return diagnostics
end

return ---@type Linter
{
        automatic = false,

        cmd = 'clang-tidy',

        args = function(context)
                local database = compilation_database(context.root)

                if database ~= nil then
                        return {
                                '--quiet',
                                '-p',
                                database,
                                context.filename,
                        }
                end

                return {
                        '--quiet',
                        context.filename,
                }
        end,

        append_fname = false,

        cwd = function(context)
                return context.root
        end,

        exit_codes = {
                [0] = true,
                [1] = true,
        },

        parser = parse,

        root_markers = {
                '.clang-tidy',
                'compile_commands.json',
                'CMakeLists.txt',
                'meson.build',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 60000,
}