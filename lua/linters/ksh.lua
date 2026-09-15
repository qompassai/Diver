-- #################################################################
-- /qompassai/Diver/lua/linters/ksh.lua
-- Qompass AI Diver Native KornShell 93u+m Syntax Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
---@source https://github.com/ksh93/ksh
---@source https://www.kornshell.com/doc/man/man1/ksh.html

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 256
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 4 * 1024 * 1024
local TIMEOUT_MS = 30000

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'ksh'

---@class KshParsedDiagnostic
---@field line integer
---@field column integer
---@field severity integer
---@field code string
---@field message string

---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
    assert(fallback >= 0)

    local parsed = tonumber(value)

    if parsed == nil then
        return fallback
    end

    parsed = floor(parsed)

    if parsed < 0 then
        return fallback
    end

    return parsed
end

---@param value string
---@return string
local function trim(value)
    assert(type(value) == 'string')

    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function strip_ansi(value)
    assert(type(value) == 'string')

    return (value:gsub('\u0017%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
    assert(type(value) == 'string')

    value = strip_ansi(value)
    value = value:gsub('
', '
')
    value = value:gsub('
', '
')
    value = trim(value)

    if #value > MESSAGE_LENGTH_MAX then
        value = value:sub(1, MESSAGE_LENGTH_MAX) .. '
[message truncated]'
    end

    return value
end

---@param line string
---@return KshParsedDiagnostic?
local function parse_line(line)
    assert(type(line) == 'string')

    if line == '' or #line > LINE_LENGTH_MAX then
        return nil
    end

    line = normalize_message(line)

    if line == '' then
        return nil
    end

    --
    -- Common ksh93 syntax-error layout:
    --
    --   ksh: /path/script.ksh[12]: syntax error at line 19: `fi' unexpected
    --
    -- The bracket line may describe the active parsing context. Prefer the
    -- explicit "syntax error at line N" location when available.
    --
    local bracket_line, syntax_line, syntax_message =
        line:match('^.-:%s*.-%[(%d+)%]:%s*syntax error at line (%d+):%s*(.+)$')

    if bracket_line ~= nil and syntax_line ~= nil and syntax_message ~= nil then
        local parsed_line = integer(syntax_line, 0)

        if parsed_line < 1 then
            parsed_line = integer(bracket_line, 0)
        end

        local message = normalize_message(syntax_message)

        if parsed_line < 1 or message == '' then
            return nil
        end

        return {
            line = parsed_line,
            column = 1,
            severity = ERROR,
            code = 'syntax',
            message = message,
        }
    end

    --
    -- Generic shell diagnostic layouts:
    --
    --   ksh: /path/script.ksh: line 12: syntax error: ...
    --   /path/script.ksh: line 12: syntax error: ...
    --
    local source_line, generic_message =
        line:match('^.-:%s*.-:%s*[Ll]ine%s+(%d+):%s*(.+)$')

    if source_line ~= nil and generic_message ~= nil then
        local parsed_line = integer(source_line, 0)
        local message = normalize_message(generic_message)

        if parsed_line < 1 or message == '' then
            return nil
        end

        return {
            line = parsed_line,
            column = 1,
            severity = ERROR,
            code = 'syntax',
            message = message,
        }
    end

    --
    -- Common warning layout:
    --
    --   ksh: /path/script.ksh[12]: warning: ...
    --
    local warning_line, warning_message =
        line:match('^.-:%s*.-%[(%d+)%]:%s*[Ww]arning:%s*(.+)$')

    if warning_line ~= nil and warning_message ~= nil then
        local parsed_line = integer(warning_line, 0)
        local message = normalize_message(warning_message)

        if parsed_line < 1 or message == '' then
            return nil
        end

        return {
            line = parsed_line,
            column = 1,
            severity = WARN,
            code = 'warning',
            message = message,
        }
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

    assert(type(output) == 'string')
    assert(type(context) == 'table', 'ksh parser requires a LintContext')

    ---@cast context LintContext

    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')
    assert(type(context.root) == 'string')
    assert(context.root ~= '')
    assert(#output <= OUTPUT_LENGTH_MAX, 'ksh output exceeded maximum size')

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for raw_line in output:gmatch('[^
]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local entry = parse_line(raw_line)

        if entry ~= nil then
            local lnum = max(entry.line - 1, 0)
            local col = max(entry.column - 1, 0)

            diagnostics[#diagnostics + 1] = {
                lnum = lnum,
                end_lnum = lnum,

                col = col,
                end_col = col + 1,

                severity = entry.severity,

                source = SOURCE,

                code = entry.code,

                message = entry.message,

                user_data = {
                    analyzer = 'ksh93-noexec',
                },
            }
        end
    end

    --
    -- ksh returned diagnostic text, but its particular version emitted a
    -- layout this parser did not recognize. Surface it at the file start
    -- instead of silently reporting the file as valid.
    --
    if #diagnostics == 0 then
        local message = normalize_message(output)

        if message ~= '' then
            diagnostics[1] = {
                lnum = 0,
                end_lnum = 0,

                col = 0,
                end_col = 1,

                severity = ERROR,

                source = SOURCE,

                code = 'syntax',

                message = message,

                user_data = {
                    analyzer = 'ksh93-noexec',
                    location = 'unparsed',
                },
            }
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX)

    return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')
    assert(type(context.root) == 'string')
    assert(context.root ~= '')

    --
    -- -n:
    --   Parse the script and report syntax errors without executing commands.
    --
    -- --:
    --   End option processing so a filename beginning with "-" cannot be
    --   interpreted as a ksh command-line option.
    --
    return {
        '-n',
        '--',
        context.filename,
    }
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(type(context.root) == 'string')
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

return ---@type Linter
{
    --
    -- ksh -n does not execute the checked script. It is suitable for
    -- automatic lint-on-save behavior.
    --
    automatic = true,

    --
    -- This must resolve to a ksh93-compatible executable.
    --
    cmd = 'ksh',

    args = args,

    --
    -- The filename is already passed explicitly by args().
    --
    append_fname = false,

    cwd = cwd,

    --
    -- A non-zero exit code is expected for syntax failures. The parser must
    -- still receive stderr and publish its diagnostics.
    --
    ignore_exitcode = true,

    parser = parse,

    --
    -- KornShell has no project manifest. Git is a conservative root boundary.
    --
    root_markers = {
        '.git',
    },

    --
    -- ksh -n validates the saved on-disk script file. Do not pass unsaved
    -- buffer text through stdin: it changes source-path and sourcing behavior.
    --
    stdin = false,

    --
    -- ksh93 writes syntax errors and warnings to standard error.
    --
    stream = 'stderr',

    timeout = TIMEOUT_MS,
}