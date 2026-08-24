-- #################################################################
-- /qompassai/lua/linters/buf_lint.lua
-- Qompass AI Buf Lint
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
---@source https://buf.build/docs/lint/

local diagnostic = vim.diagnostic
local fs = vim.fs

local ERROR = diagnostic.severity.ERROR

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 16384

---@class BufLintViolation
---@field path? string
---@field start_line? integer
---@field start_column? integer
---@field end_line? integer
---@field end_column? integer
---@field type? string
---@field message? string

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

---@param filename string
---@param root string
---@return string
local function relative_path(filename, root)
        assert(filename ~= '')
        assert(root ~= '')

        local normalized_filename = fs.normalize(filename)
        local normalized_root = fs.normalize(root)

        if normalized_filename:sub(1, #normalized_root) == normalized_root then
                local offset = #normalized_root + 2
                local relative = normalized_filename:sub(offset)

                if relative ~= '' then
                        return relative
                end
        end

        return normalized_filename
end

---@param line string
---@return BufLintViolation?
local function decode_line(line)
        assert(#line <= LINE_LENGTH_MAX)

        local ok, decoded = pcall(vim.json.decode, line)

        if not ok or type(decoded) ~= 'table' then
                return nil
        end

        ---@cast decoded BufLintViolation
        return decoded
end

---@param violation BufLintViolation
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_violation(violation, filename, root)
        local path = violation.path

        if type(path) ~= 'string' or path == '' then
                return nil
        end

        if not belongs_to_buffer(path, filename, root) then
                return nil
        end

        local message = violation.message
        if type(message) ~= 'string' or message == '' then
                message = 'Buf lint violation'
        end

        local start_line =
                math.max(integer(violation.start_line, 1) - 1, 0)

        local start_column =
                math.max(integer(violation.start_column, 1) - 1, 0)

        local end_line = math.max(
                integer(violation.end_line, start_line + 1) - 1,
                start_line
        )

        local minimum_end_column =
                end_line == start_line
                        and start_column + 1
                        or 0

        local end_column = math.max(
                integer(
                        violation.end_column,
                        minimum_end_column + 1
                ) - 1,
                minimum_end_column
        )

        return {
                lnum = start_line,
                end_lnum = end_line,
                col = start_column,
                end_col = end_column,
                message = message,
                severity = ERROR,
                source = 'buf',
                code = violation.type,
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
                'buf_lint parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        local filename = fs.normalize(context.filename)
        local root = context.root

        ---@type vim.Diagnostic.Set[]
        local diagnostics = {}
        local diagnostics_count = 0

        --
        -- Buf emits one JSON object per violation rather than one JSON array.
        --
        for line in output:gmatch('[^\r\n]+') do
                if diagnostics_count >= DIAGNOSTICS_MAX then
                        break
                end

                if #line <= LINE_LENGTH_MAX then
                        local violation = decode_line(line)

                        if violation ~= nil then
                                local entry = diagnostic_from_violation(
                                        violation,
                                        filename,
                                        root
                                )

                                if entry ~= nil then
                                        diagnostics_count =
                                                diagnostics_count + 1

                                        diagnostics[diagnostics_count] = entry
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

        cmd = 'buf',

        args = function(context)
                assert(context.filename ~= '')
                assert(context.root ~= '')

                return {
                        'lint',
                        '.',
                        '--error-format=json',
                        '--path',
                        relative_path(
                                context.filename,
                                context.root
                        ),
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
                'buf.yaml',
                'buf.work.yaml',
                'buf.lock',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}