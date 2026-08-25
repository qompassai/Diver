-- #################################################################
-- /qompassai/Diver/lua/linters/dxc.lua
-- Qompass AI DXC
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
---@source https://github.com/microsoft/DirectXShaderCompiler

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

---@class DxcViolation
---@field code? string
---@field column integer
---@field file string
---@field line integer
---@field message string
---@field severity string

---@type table<string, integer>
local severities = {
        error = ERROR,
        fatal = ERROR,
        note = INFO,
        remark = HINT,
        warning = WARN,
}

---@param value integer|number|string|nil
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

---@param level string|nil
---@return integer
local function severity(level)
        if level == nil then
                return WARN
        end

        return severities[level:lower()] or WARN
end

---@param path string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(path, filename, root)
        assert(path ~= '')
        assert(filename ~= '')
        assert(root ~= '')

        if path == '-' or path == '<stdin>' then
                return true
        end

        local candidate

        if fs.is_absolute(path) then
                candidate = fs.normalize(path)
        else
                candidate = fs.normalize(
                        fs.joinpath(root, path)
                )
        end

        return candidate == filename
end

---@param line string
---@return DxcViolation?
local function parse_line(line)
        if line == '' then
                return nil
        end

        --
        -- Clang-style DXC output:
        --
        -- path/file.hlsl:12:7: warning: message [-Wfoo]
        -- path/file.hlsl:12:7: error: message
        --
        local file,
                line_number,
                column_number,
                level,
                message =
                line:match(
                        '^(.+):(%d+):(%d+): '
                        .. '([%a]+): (.+)$'
                )

        if
                file == nil
                or line_number == nil
                or column_number == nil
                or level == nil
                or message == nil
        then
                return nil
        end

        local code =
                message:match('%[([^%]]+)%]%s*$')

        if code ~= nil then
                message = message:gsub(
                        '%s*%[[^%]]+%]%s*$',
                        ''
                )
        end

        return {
                code = code,
                column = integer(column_number, 1),
                file = file,
                line = integer(line_number, 1),
                message = message,
                severity = level,
        }
end

---@param violation DxcViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(
        violation,
        filename,
        root
)
        if
                not belongs_to_buffer(
                        violation.file,
                        filename,
                        root
                )
        then
                return nil
        end

        local start_line = math.max(
                integer(violation.line, 1) - 1,
                0
        )

        local start_column = math.max(
                integer(violation.column, 1) - 1,
                0
        )

        local message = violation.message

        if message == '' then
                message = 'DXC diagnostic'
        end

        return {
                lnum = start_line,
                end_lnum = start_line,
                col = start_column,
                end_col = start_column + 1,
                message = message,
                severity = severity(violation.severity),
                source = 'dxc',
                code = violation.code,
        }
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
                'dxc parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        assert(
                #output <= OUTPUT_LENGTH_MAX,
                'dxc output exceeded maximum size'
        )

        local filename = fs.normalize(context.filename)
        local root = fs.normalize(context.root)

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                local violation = parse_line(line)

                if violation ~= nil then
                        local entry =
                                diagnostic_from_violation(
                                        violation,
                                        filename,
                                        root
                                )

                        if entry ~= nil then
                                diagnostics_count =
                                        diagnostics_count + 1

                                diagnostics[diagnostics_count] =
                                        entry
                        end
                end
        end

        assert(diagnostics_count <= DIAGNOSTICS_MAX)
        assert(diagnostics_count == #diagnostics)

        return diagnostics
end

---@param filename string
---@return string
local function profile_for_filename(filename)
        local name = filename:lower()

        if
                name:match('%.vert%.hlsl$')
                or name:match('%.vs%.hlsl$')
        then
                return 'vs_6_7'
        end

        if
                name:match('%.frag%.hlsl$')
                or name:match('%.pixel%.hlsl$')
                or name:match('%.ps%.hlsl$')
        then
                return 'ps_6_7'
        end

        if
                name:match('%.comp%.hlsl$')
                or name:match('%.compute%.hlsl$')
                or name:match('%.cs%.hlsl$')
        then
                return 'cs_6_7'
        end

        if
                name:match('%.geom%.hlsl$')
                or name:match('%.gs%.hlsl$')
        then
                return 'gs_6_7'
        end

        if
                name:match('%.hull%.hlsl$')
                or name:match('%.hs%.hlsl$')
        then
                return 'hs_6_7'
        end

        if
                name:match('%.domain%.hlsl$')
                or name:match('%.ds%.hlsl$')
        then
                return 'ds_6_7'
        end

        if
                name:match('%.mesh%.hlsl$')
                or name:match('%.ms%.hlsl$')
        then
                return 'ms_6_7'
        end

        if
                name:match('%.amplification%.hlsl$')
                or name:match('%.as%.hlsl$')
        then
                return 'as_6_7'
        end

        if
                name:match('%.lib%.hlsl$')
                or name:match('%.ray%.hlsl$')
                or name:match('%.rt%.hlsl$')
        then
                return 'lib_6_7'
        end

        return 'lib_6_7'
end

---@param context LintContext
---@return string[]
local function args(context)
        assert(context.filename ~= '')

        local profile =
                profile_for_filename(context.filename)

        local argv = {
                context.filename,

                -- Tiger-style strictness.
                '-Ges',
                '-Wall',

                -- HLSL 2021 semantics.
                '-HV',
                '2021',

                -- Stable machine-parsable diagnostics.
                '-fdiagnostics-format=clang',
                '-fdiagnostics-show-option',

                -- Prevent diagnostic explosions from malformed shaders.
                '-ferror-limit=100',

                -- Validate only; do not optimize editor lint runs heavily.
                '-O0',

                -- Compile according to the inferred stage.
                '-T',
                profile,
        }

        --
        -- Library profiles intentionally do not require an entry point.
        --
        -- For stage-specific profiles DXC requires one, so use the
        -- conventional `main` entry point. Projects with different entry
        -- points should expose that through project-specific configuration.
        --
        if not profile:match('^lib_') then
                argv[#argv + 1] = '-E'
                argv[#argv + 1] = 'main'
        end

        return argv
end

return ---@type Linter
{
        automatic = false,

        cmd = 'dxc',

        args = args,

        append_fname = false,

        cwd = function(context)
                assert(context.root ~= '')

                return context.root
        end,

        ignore_exitcode = true,

        parser = parse,

        root_markers = {
                'CMakeLists.txt',
                'meson.build',
                'premake5.lua',
                'xmake.lua',
                '.git',
        },

        stdin = false,

        --
        -- DXC normally writes diagnostics to stderr.
        --
        stream = 'stderr',

        timeout = 30000,
}