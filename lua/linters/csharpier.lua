-- #################################################################
-- /qompassai/lua/linters/csharpier.lua
-- Qompass AI CSharpier
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
-- /qompassai/Diver/lua/linters/csharpier.lua
-- Qompass AI Diver Native CSharpier Linter
-- SPDX-License-Identifier: Apache-2.0
--
-- CSharpier is fundamentally a formatter. This native linter configuration
-- deliberately invokes only:
--
--     csharpier check <file>
--
-- so linting can never modify the current buffer or source file.
-- #################################################################

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

---@class CSharpierCheck
---@field file? string
---@field message string
---@field severity integer

---@type table<string, integer>
local severities = {
        error = diagnostic.severity.ERROR,
        information = diagnostic.severity.INFO,
        info = diagnostic.severity.INFO,
        warning = diagnostic.severity.WARN,
        warn = diagnostic.severity.WARN,
}

---@type string[]
local root_markers = {
        '.config/dotnet-tools.json',
        '.csharpierrc',
        '.editorconfig',
        '.git',
        'Directory.Build.props',
        'Directory.Build.targets',
        'Directory.Packages.props',
        'global.json',
}

---Return whether a path exists.
---@param path string
---@return boolean
local function exists(path)
        return uv.fs_stat(path) ~= nil
end

---Normalize a path for comparison.
---@param path string
---@return string
local function normalize(path)
        return fs.normalize(path)
end

---Resolve a relative path against the linter root.
---@param path string
---@param root string
---@return string
local function absolute(path, root)
        if path:sub(1, 1) == '/' then
                return normalize(path)
        end

        return normalize(
                fs.joinpath(root, path)
        )
end

---Strip surrounding whitespace and ANSI terminal escape sequences.
---
---CSharpier normally emits plain text when used non-interactively, but
---removing ANSI sequences here keeps diagnostics stable if terminal coloring
---is enabled by the environment.
---@param value string
---@return string
local function clean(value)
        value = value:gsub('\27%[[%d;]*m', '')

        return vim.trim(value)
end

---Parse one CSharpier status line.
---
---Current CSharpier check output for an unformatted source file takes the
---general form:
---
---    Error ./TestData.cs - Was not formatted.
---
---The command may also emit warnings or informational messages using the same
---prefix structure.
---
---@param line string
---@return CSharpierCheck?
local function parse_status(line)
        line = clean(line)

        local level, file, message = line:match(
                '^([%a]+)%s+(.+)%s+%-%s+(.+)$'
        )

        if level == nil or message == nil then
                return nil
        end

        local severity_name = level:lower()

        if severities[severity_name] == nil then
                return nil
        end

        return {
                file = clean(file or ''),
                message = clean(message),
                severity = severities[severity_name],
        }
end

---Parse CSharpier's check output into native Neovim diagnostics.
---
---CSharpier reports formatting at file granularity rather than identifying a
---specific source position. Formatting diagnostics are therefore anchored at
---line 1, column 1 of the current buffer.
---
---Verbose expected/actual formatting diffs are intentionally not converted to
---individual diagnostics; the initial "Was not formatted" result represents
---the actionable condition without flooding vim.diagnostic.
---
---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, context)
        if vim.trim(output) == '' then
                return {}
        end

        local diagnostics = {}

        for line in vim.gsplit(output, '\n', {
                plain = true,
                trimempty = true,
        }) do
                local result = parse_status(line)

                if result ~= nil then
                        local diagnostic_file

                        if result.file ~= nil and result.file ~= '' then
                                diagnostic_file = absolute(
                                        result.file,
                                        context.root
                                )
                        end

                        -- When linting one file, ignore status lines that clearly
                        -- belong to some other source file.
                        if
                                diagnostic_file == nil
                                or normalize(diagnostic_file)
                                        == normalize(context.filename)
                        then
                                diagnostics[#diagnostics + 1] = {
                                        code = 'CSHARPIER',
                                        col = 0,
                                        end_col = 1,
                                        end_lnum = 0,
                                        lnum = 0,
                                        message = result.message,
                                        severity = result.severity,
                                        source = 'csharpier',
                                        user_data = {
                                                filename = diagnostic_file,
                                        },
                                }
                        end
                end
        end

        return diagnostics
end

---Determine whether the project uses a local dotnet tool manifest.
---
---When `.config/dotnet-tools.json` exists, invoking CSharpier through `dotnet
---tool run csharpier` ensures the project-pinned version is used instead of a
---potentially different global CSharpier installation.
---
---@param root string
---@return boolean
local function has_tool_manifest(root)
        return exists(
                fs.joinpath(
                        root,
                        '.config',
                        'dotnet-tools.json'
                )
        )
end

---Resolve the CSharpier command.
---
---Preference:
---
---1. Project-local dotnet tool manifest:
---       dotnet tool run csharpier ...
---
---2. Globally installed CSharpier:
---       csharpier ...
---
---@param context LintContext
---@return string
local function command(context)
        if has_tool_manifest(context.root) then
                return 'dotnet'
        end

        return 'csharpier'
end

---Build CSharpier arguments for the current file.
---
---`check`
---    Performs a read-only formatting verification.
---
---`--use-cache`
---    Allows current CSharpier releases to reuse their formatting cache during
---    checks. This option was added to the check command in CSharpier 1.3.
---
---When a dotnet tool manifest exists, the command becomes:
---
---    dotnet tool run csharpier -- check --use-cache <file>
---
---Otherwise:
---
---    csharpier check --use-cache <file>
---
---@param context LintContext
---@return string[]
local function args(context)
        local arguments = {}

        if has_tool_manifest(context.root) then
                vim.list_extend(arguments, {
                        'tool',
                        'run',
                        'csharpier',
                        '--',
                })
        end

        vim.list_extend(arguments, {
                'check',
                '--use-cache',
                context.filename,
        })

        return arguments
end

---Run CSharpier from the detected project root.
---
---This allows normal discovery of `.csharpierrc`, `.editorconfig`, local
---dotnet tool manifests, `.gitignore`, and project configuration.
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

        -- 0: all checked files are formatted.
        -- 1: one or more files require formatting.
        --
        -- Exit code 1 is therefore valid diagnostic output rather than a
        -- linter process failure.
        exit_codes = {
                [0] = true,
                [1] = true,
        },

        parser = parse,

        root_markers = root_markers,

        stdin = false,

        -- CSharpier's check/status output is consumed as normal process output.
        stream = 'stdout',

        timeout = 30000,
}