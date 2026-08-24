-- #################################################################
-- /qompassai/lua/linters/biome.lua
-- Qompass AI Biome
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
---@source https://biomejs.dev/linter/

local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local fn = vim.fn

local ERROR = diagnostic.severity.ERROR
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 16384
local MAX_DIAGNOSTICS = 1000

---@type table<string, string>
local executable_cache = {}

---@type table<string, integer>
local severities = {
        ['×'] = ERROR,
        ['!'] = WARN,
        ['i'] = INFO,
}

---@param root string
---@return string
local function executable(root)
        assert(root ~= '')

        local cached = executable_cache[root]
        if cached ~= nil then
                return cached
        end

        local local_cmd = fs.joinpath(
                root,
                'node_modules',
                '.bin',
                'biome'
        )

        if fn.executable(local_cmd) == 1 then
                executable_cache[root] = local_cmd
                return local_cmd
        end

        executable_cache[root] = 'biome'
        return 'biome'
end

---@param filename string
---@return integer?
local function buffer_for_filename(filename)
        assert(filename ~= '')

        local bufnr = fn.bufnr(filename, false)

        if bufnr < 0 or not api.nvim_buf_is_valid(bufnr) then
                return nil
        end

        return bufnr
end

---@param filename string
---@return boolean
local function biome_lsp_attached(filename)
        assert(filename ~= '')

        local bufnr = buffer_for_filename(filename)
        if bufnr == nil then
                return false
        end

        local clients = vim.lsp.get_clients({
                bufnr = bufnr,
                name = 'biome',
        })

        return #clients > 0
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

---@param line string
---@return string?, integer?, integer?, string?, string?, integer?
local function parse_line(line)
        assert(#line <= LINE_LENGTH_MAX)

        --
        -- Biome concise reporter:
        --
        --   ! index.ts:2:10: lint/correctness/noUnusedImports:
        --     Several of these imports are unused.
        --
        -- Current output normally emits the complete diagnostic on one line:
        --
        --   ! index.ts:2:10: lint/correctness/noUnusedImports: Several...
        --   × main.ts:2:10: lint/suspicious/noRedeclare: Shouldn't...
        --
        local symbol
        local path
        local line_number
        local column_number
        local code
        local message

        symbol,
                path,
                line_number,
                column_number,
                code,
                message =
                line:match(
                        '^%s*([×!i])%s+(.+):(%d+):(%d+):%s+([^:]+):%s+(.+)$'
                )

        if symbol == nil then
                return nil
        end

        local level = severities[symbol]

        if level == nil then
                return nil
        end

        return path,
                integer(line_number, 1),
                integer(column_number, 1),
                code,
                message,
                level
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
                'biome parser requires a LintContext'
        )

        ---@cast context LintContext

        assert(context.filename ~= '')
        assert(context.root ~= '')

        --
        -- The LSP already publishes Biome diagnostics for this buffer.
        --
        -- Returning no CLI diagnostics prevents:
        --
        --   * duplicate virtual text
        --   * duplicate signs
        --   * duplicate location-list entries
        --   * differing LSP/CLI rule configuration appearing simultaneously
        --
        if biome_lsp_attached(context.filename) then
                return {}
        end

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
                        local column_number
                        local code
                        local message
                        local level

                        path,
                                line_number,
                                column_number,
                                code,
                                message,
                                level = parse_line(line)

                        if
                                path ~= nil
                                and line_number ~= nil
                                and column_number ~= nil
                                and code ~= nil
                                and message ~= nil
                                and level ~= nil
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
                                        message = message,
                                        severity = level,
                                        source = 'biome',
                                        code = code,
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

        cmd = function(context)
                assert(context.root ~= '')

                return executable(context.root)
        end,

        args = function(context)
                assert(context.filename ~= '')

                return {
                        'lint',
                        '--colors=off',
                        '--max-diagnostics=' .. MAX_DIAGNOSTICS,
                        '--reporter=concise',
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
                'biome.json',
                'biome.jsonc',
                'bun.lock',
                'bun.lockb',
                'package-lock.json',
                'pnpm-lock.yaml',
                'yarn.lock',
                '.git',
        },

        stdin = false,
        stream = 'stdout',
        timeout = 30000,
}