-- #################################################################
-- /qompassai/lua/linters/vulture.lua
-- Qompass AI Vulture
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
---@source https://github.com/jendrikseipp/vulture

local diagnostic = vim.diagnostic
local fs = vim.fs

local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 16384
local MIN_CONFIDENCE = 80

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

---@param confidence integer
---@return integer
local function severity(confidence)
        assert(confidence >= MIN_CONFIDENCE)
        assert(confidence <= 100)

        if confidence == 100 then
                return WARN
        end

        if confidence >= 90 then
                return INFO
        end

        return HINT
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
---@return string?, integer?, string?, integer?
local function parse_line(line)
        assert(#line <= LINE_LENGTH_MAX)

        --
        -- Vulture output:
        --
        --   foo.py:1: unused import 'os' (90% confidence)
        --   foo.py:4: unused function 'greet' (60% confidence)
        --
        local path
        local line_number
        local message
        local confidence

        path, line_number, message, confidence =
                line:match(
                        '^(.+):(%d+):%s+(.+)%s+%((%d+)%%%s+confidence%)$'
                )

        if path == nil then
                return nil
        end

        local confidence_number = integer(confidence, 0)

        if
                confidence_number < MIN_CONFIDENCE
                or confidence_number > 100
        then
                return nil
        end

        return path,
                integer(line_number, 1),
                message,
                confidence_number
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
                'vulture parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                if #line <= LINE_LENGTH_MAX then
                        local path
                        local line_number
                        local message
                        local confidence

                        path,
                        line_number,
                        message,
                        confidence = parse_line(line)

                        if
                                path ~= nil
                                and line_number ~= nil
                                and message ~= nil
                                and confidence ~= nil
                                and belongs_to_buffer(
                                        path,
                                        filename,
                                        root
                                )
                        then
                                local row = math.max(line_number - 1, 0)

                                diagnostics_count = diagnostics_count + 1

                                diagnostics[diagnostics_count] = {
                                        lnum = row,
                                        end_lnum = row,
                                        col = 0,
                                        end_col = 1,
                                        message = message,
                                        severity = severity(confidence),
                                        source = 'vulture',
                                        code = ('confidence:%d'):format(
                                                confidence
                                        ),
                                        user_data = {
                                                confidence = confidence,
                                        },
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

        cmd = 'vulture',

        args = function(context)
                assert(context.filename ~= '')

                return {
                        '--min-confidence',
                        tostring(MIN_CONFIDENCE),
                        '--sort-by-size',
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
                'pyproject.toml',
                'setup.cfg',
                'setup.py',
                'tox.ini',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}