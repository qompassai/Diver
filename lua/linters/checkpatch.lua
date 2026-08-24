-- #################################################################
-- /qompassai/lua/linters/checkpatch.lua
-- Qompass AI Checkpatch
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
local fn = vim.fn

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 16384

---@type table<string, integer>
local severities = {
        ERROR = ERROR,
        WARNING = WARN,
        CHECK = INFO,
}

---@type table<string, string>
local command_cache = {}

---@param root string
---@return string
local function command(root)
        assert(root ~= '')

        local cached = command_cache[root]
        if cached ~= nil then
                return cached
        end

        local local_script = fs.joinpath(
                root,
                'scripts',
                'checkpatch.pl'
        )

        if fn.executable(local_script) == 1 then
                command_cache[root] = local_script
                return local_script
        end

        if fn.executable('checkpatch.pl') == 1 then
                command_cache[root] = 'checkpatch.pl'
                return 'checkpatch.pl'
        end

        command_cache[root] = 'scripts/checkpatch.pl'
        return 'scripts/checkpatch.pl'
end

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

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
        assert(path ~= '')
        assert(filename ~= '')
        assert(root ~= '')

        local candidate

        if fs.is_absolute(path) then
                candidate = fs.normalize(path)
        else
                candidate = fs.normalize(fs.joinpath(root, path))
        end

        return candidate == filename
end

---@param line string
---@return string?, string?, string?, integer?, integer?
local function parse_location(line)
        assert(#line <= LINE_LENGTH_MAX)

        --
        -- Typical --terse --showfile output:
        --
        -- ERROR:CODE_INDENT: code indent should use tabs where possible
        -- #12: FILE: drivers/foo/bar.c:42:
        --
        -- WARNING:LONG_LINE: line length of 105 exceeds 100 columns
        -- #27: FILE: drivers/foo/bar.c:81:
        --
        -- Some versions may include a column:
        --
        -- #27: FILE: drivers/foo/bar.c:81:9:
        --
        local path
        local line_number
        local column_number

        path, line_number, column_number =
                line:match(
                        '^#%d+:%s+FILE:%s+(.+):(%d+):(%d+):%s*$'
                )

        if path ~= nil then
                return path,
                        nil,
                        nil,
                        integer(line_number, 1),
                        integer(column_number, 1)
        end

        path, line_number =
                line:match(
                        '^#%d+:%s+FILE:%s+(.+):(%d+):%s*$'
                )

        if path ~= nil then
                return path,
                        nil,
                        nil,
                        integer(line_number, 1),
                        1
        end

        return nil
end

---@param line string
---@return integer?, string?, string?
local function parse_header(line)
        assert(#line <= LINE_LENGTH_MAX)

        --
        -- checkpatch diagnostic header:
        --
        --   ERROR:CODE_INDENT: code indent should use tabs where possible
        --   WARNING:LONG_LINE: line length of 105 exceeds 100 columns
        --   CHECK:PARENTHESIS_ALIGNMENT: Alignment should match open parenthesis
        --
        local level
        local code
        local message

        level, code, message =
                line:match(
                        '^(ERROR|WARNING|CHECK):([^:]+):%s*(.+)$'
                )

        if level == nil then
                return nil
        end

        local severity = severities[level]

        if severity == nil then
                return nil
        end

        return severity, code, message
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
                'checkpatch parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        local pending_severity
        local pending_code
        local pending_message

        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                if #line <= LINE_LENGTH_MAX then
                        local level
                        local code
                        local message

                        level, code, message = parse_header(line)

                        if
                                level ~= nil
                                and code ~= nil
                                and message ~= nil
                        then
                                pending_severity = level
                                pending_code = code
                                pending_message = message
                        elseif
                                pending_severity ~= nil
                                and pending_message ~= nil
                        then
                                local path
                                local line_number
                                local column_number

                                path,
                                        _,
                                        _,
                                        line_number,
                                        column_number =
                                        parse_location(line)

                                if
                                        path ~= nil
                                        and line_number ~= nil
                                        and column_number ~= nil
                                        and belongs_to_buffer(
                                                path,
                                                filename,
                                                root
                                        )
                                then
                                        local row = math.max(
                                                line_number - 1,
                                                0
                                        )

                                        local column = math.max(
                                                column_number - 1,
                                                0
                                        )

                                        diagnostics_count =
                                                diagnostics_count + 1

                                        diagnostics[diagnostics_count] = {
                                                lnum = row,
                                                end_lnum = row,
                                                col = column,
                                                end_col = column + 1,
                                                message = pending_message,
                                                severity = pending_severity,
                                                source = 'checkpatch',
                                                code = pending_code,
                                        }

                                        pending_severity = nil
                                        pending_code = nil
                                        pending_message = nil
                                end
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

        cmd = function(context)
                assert(context.root ~= '')

                return command(context.root)
        end,

        args = function(context)
                assert(context.filename ~= '')

                return {
                        '--file',
                        '--no-summary',
                        '--showfile',
                        '--terse',
                        context.filename,
                }
        end,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                'Kbuild',
                'Kconfig',
                'Makefile',
                'MAINTAINERS',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}