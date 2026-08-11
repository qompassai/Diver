-- #################################################################
-- /qompassai/lua/linters/dotnet-format.lua
-- Qompass AI Dotnet Format
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
-- /qompassai/Diver/lua/linters/dotnet-format.lua
-- Qompass AI Diver Native Dotnet Format Linter
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local severities = {
        error = diagnostic.severity.ERROR,
        info = diagnostic.severity.INFO,
        information = diagnostic.severity.INFO,
        warning = diagnostic.severity.WARN,
        warn = diagnostic.severity.WARN,
}

local root_markers = {
        '.editorconfig',
        '.git',
        'Directory.Build.props',
        'Directory.Build.targets',
        'Directory.Packages.props',
        'global.json',
        '*.csproj',
        '*.fsproj',
        '*.sln',
        '*.slnx',
        '*.vbproj',
}

local workspace_extensions = {
        '.slnx',
        '.sln',
        '.csproj',
        '.fsproj',
        '.vbproj',
}

---@param path string
---@return boolean
local function exists(path)
        return uv.fs_stat(path) ~= nil
end

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

---@param path string
---@return string
local function normalize(path)
        return fs.normalize(path)
end

---@param path string
---@param root string
---@return boolean
local function is_absolute(path, root)
        return normalize(path) == normalize(root)
                or normalize(path):sub(1, #normalize(root) + 1)
                        == normalize(root) .. '/'
end

---@param path string
---@param root string
---@return string
local function absolute(path, root)
        if path:sub(1, 1) == '/' then
                return normalize(path)
        end

        return normalize(fs.joinpath(root, path))
end

---@param filename string
---@return string
local function extension(filename)
        return filename:match('(%.[^./]+)$') or ''
end

---@param root string
---@return string[]
local function directory_entries(root)
        local entries = {}
        local handle = uv.fs_scandir(root)

        if handle == nil then
                return entries
        end

        while true do
                local name, kind = uv.fs_scandir_next(handle)

                if name == nil then
                        break
                end

                if kind == 'file' then
                        entries[#entries + 1] = name
                end
        end

        table.sort(entries)

        return entries
end

---@param root string
---@return string?
local function workspace(root)
        local entries = directory_entries(root)

        -- Prefer solution workspaces over individual projects.
        for _, wanted_extension in ipairs(workspace_extensions) do
                for _, name in ipairs(entries) do
                        if extension(name) == wanted_extension then
                                return fs.joinpath(root, name)
                        end
                end
        end

        return nil
end

---@param path string
---@return string
local function escape_pattern(path)
        return path:gsub('([^%w])', '%%%1')
end

---@param line string
---@return string?, integer?, integer?, string?, string?, string?
local function parse_line(line)
        --
        -- Roslyn/MSBuild diagnostic format:
        --
        -- /path/Foo.cs(3,21): error WHITESPACE: Fix whitespace formatting.
        -- /path/Foo.cs(5,10): warning IDE0005: Using directive is unnecessary.
        --
        local filename, lnum, column, severity, code, message =
                line:match(
                        '^%s*(.-)%((%d+),(%d+)%)'
                                .. ':%s*([%a]+)%s+([^:%s]+)'
                                .. ':%s*(.-)%s*$'
                )

        if filename == nil then
                return nil
        end

        return filename,
                integer(lnum, 1),
                integer(column, 1),
                severity,
                code,
                message
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        local diagnostics = {}

        local root

        if type(context) == 'table' then
                root = context.root
        else
                root = vim.fn.getcwd()
        end

        for line in vim.gsplit(output, '\n', {
                plain = true,
                trimempty = true,
        }) do
                local filename,
                        lnum,
                        column,
                        severity,
                        code,
                        message = parse_line(line)

                if
                        filename ~= nil
                        and lnum ~= nil
                        and column ~= nil
                        and severity ~= nil
                        and message ~= nil
                then
                        --
                        -- dotnet format may append an MSBuild project suffix:
                        --
                        --   [/path/project.csproj]
                        --
                        -- Strip it from the human-readable diagnostic text.
                        --
                        message = message:gsub('%s+%[[^%]]+%]%s*$', '')

                        local diagnostic_file = absolute(filename, root)
                        local level = severity:lower()
                        local line_number = math.max(lnum - 1, 0)
                        local start_column = math.max(column - 1, 0)

                        diagnostics[#diagnostics + 1] = {
                                code = code,
                                col = start_column,
                                end_col = start_column + 1,
                                end_lnum = line_number,
                                lnum = line_number,
                                message = code ~= nil and code ~= ''
                                                and ('[%s] %s'):format(code, message)
                                        or message,
                                severity = severities[level]
                                        or diagnostic.severity.WARN,
                                source = 'dotnet-format',
                                user_data = {
                                        filename = diagnostic_file,
                                },
                        }
                end
        end

        return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
        local arguments = {
                'format',
        }

        local target = workspace(context.root)

        if target ~= nil and exists(target) then
                arguments[#arguments + 1] = target
        end

        arguments[#arguments + 1] = '--include'
        arguments[#arguments + 1] = context.filename

        arguments[#arguments + 1] = '--no-restore'

        arguments[#arguments + 1] = '--severity'
        arguments[#arguments + 1] = 'info'

        arguments[#arguments + 1] = '--verify-no-changes'

        arguments[#arguments + 1] = '--verbosity'
        arguments[#arguments + 1] = 'diagnostic'

        return arguments
end

---@param context LintContext
---@return string
local function cwd(context)
        return context.root
end

return ---@type Linter
{
        append_fname = false,
        args = args,
        cmd = 'dotnet',
        cwd = cwd,
        exit_codes = {
                [0] = true,
                [2] = true,
        },
        parser = parse,
        root_markers = root_markers,
        stdin = false,
        stream = 'both',
        timeout = 120000,
}