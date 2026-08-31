-- #################################################################
-- /qompassai/Diver/lua/linters/erb_lint.lua
-- Qompass AI Diver Native ERB Lint Linter
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
---@source https://github.com/Shopify/erb_lint
local diagnostic = vim.diagnostic
local fs = vim.fs
local ERROR = diagnostic.severity.ERROR
local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type
local SOURCE = 'erb_lint'
local CODE = 'erb-lint'
---@class ErbLintParsedDiagnostic
---@field filename string
---@field line integer
---@field column integer
---@field message string
---@param value integer|number|string|nil
---@param fallback integer
---@return integer
local function integer(value, fallback)
    assert(fallback >= 0, 'fallback must be non-negative')
    local parsed = tonumber(value)

    if parsed == nil then
        return fallback
    end

    return floor(parsed)
end

---@param value string
---@return string
local function trim(value)
    assert(type(value) == 'string', 'value must be a string')

    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return string
local function strip_ansi(value)
    assert(type(value) == 'string', 'value must be a string')

    return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
    assert(type(value) == 'string', 'value must be a string')

    value = strip_ansi(value)

    value = value:gsub('\r\n', '\n')

    value = value:gsub('\r', '\n')

    value = trim(value)

    if #value > MESSAGE_LENGTH_MAX then
        value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
    end

    return value
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
    assert(type(path) == 'string' and path ~= '', 'path must be a non-empty string')

    assert(type(root) == 'string' and root ~= '', 'root must be a non-empty string')

    --
    -- Convert file:// URIs before performing filesystem normalization.
    --
    if path:sub(1, 7) == 'file://' then
        local ok, filename = pcall(vim.uri_to_fname, path)

        if ok and type(filename) == 'string' and filename ~= '' then
            return fs.normalize(fs.abspath(filename))
        end
    end

    --
    -- vim.fs.abspath() handles both absolute and relative paths. Supplying
    -- `root` as the base avoids relying on vim.fs.is_absolute(), which is not
    -- present in the Neovim 0.13 vim.fs type surface.
    --
    return fs.normalize(fs.abspath(path, {
        base = root,
    }))
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(candidate, filename, root)
    assert(candidate ~= '', 'candidate must not be empty')

    assert(filename ~= '', 'filename must not be empty')

    assert(root ~= '', 'root must not be empty')

    local candidate_path = normalize_path(candidate, root)

    local buffer_path = normalize_path(filename, root)

    return candidate_path == buffer_path
end

---@param line string
---@return ErbLintParsedDiagnostic?
local function parse_line(line)
    assert(type(line) == 'string', 'line must be a string')

    if line == '' or #line > LINE_LENGTH_MAX then
        return nil
    end

    line = strip_ansi(line)

    --
    -- ERB Lint compact formatter:
    --
    --   app/views/example.html.erb:27:37: Extra space detected...
    --
    -- Non-diagnostic summary/progress output deliberately fails this grammar.
    --
    local filename, line_text, column_text, message = line:match('^(.+):(%d+):(%d+):%s*(.+)$')

    if filename == nil or line_text == nil or column_text == nil or message == nil then
        return nil
    end

    local line_number = integer(line_text, 0)

    local column = integer(column_text, 0)

    if line_number < 1 then
        return nil
    end

    if column < 0 then
        return nil
    end

    message = normalize_message(message)

    if message == '' then
        return nil
    end

    return {
        filename = filename,
        line = line_number,
        column = column,
        message = message,
    }
end

---@param entry ErbLintParsedDiagnostic
---@param bufnr integer
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(entry, bufnr, filename, root)
    if not belongs_to_buffer(entry.filename, filename, root) then
        return nil
    end

    --
    -- ERB Lint compact output uses one-based lines but can legitimately emit
    -- column zero. Preserve the reported column while converting the line to
    -- Neovim's zero-based coordinate system.
    --
    local lnum = max(entry.line - 1, 0)

    local col = max(entry.column, 0)

    return {
        bufnr = bufnr,

        lnum = lnum,
        end_lnum = lnum,

        col = col,
        end_col = col + 1,

        message = entry.message,

        severity = ERROR,

        source = SOURCE,
        code = CODE,

        user_data = {
            formatter = 'compact',
        },
    }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    assert(type(context) == 'table', 'erb_lint parser requires a LintContext')

    ---@cast context LintContext

    assert(type(context.bufnr) == 'number' and context.bufnr >= 0, 'context.bufnr must be a valid buffer number')

    assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

    assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

    assert(#output <= OUTPUT_LENGTH_MAX, 'erb_lint output exceeded maximum size')

    local filename = normalize_path(context.filename, context.root)

    local root = fs.normalize(fs.abspath(context.root))

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for raw_line in output:gmatch('[^\r\n]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local entry = parse_line(raw_line)

        if entry ~= nil then
            local result = diagnostic_from_entry(entry, context.bufnr, filename, root)

            if result ~= nil then
                diagnostics[#diagnostics + 1] = result
            end
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX, 'diagnostic limit exceeded')

    return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
    assert(type(context.filename) == 'string' and context.filename ~= '', 'context.filename must be a non-empty string')

    return {
        --
        -- Compact provides deterministic single-line diagnostics:
        --
        --   filename:line:column: message
        --
        '--format',
        'compact',

        --
        -- Analyze exactly the active ERB file rather than recursively traversing
        -- the repository.
        --
        context.filename,
    }
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(type(context.root) == 'string' and context.root ~= '', 'context.root must be a non-empty string')

    return fs.normalize(fs.abspath(context.root))
end

return ---@type Linter
{
    automatic = false,

    cmd = {
        'erb_lint',
        'erblint',
        'erb-lint',
    },

    args = args,

    append_fname = false,

    cwd = cwd,

    --
    -- ERB Lint returns a nonzero status when lint violations are present.
    --
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        --
        -- Current ERB Lint configuration.
        --
        '.erb_lint.yml',

        --
        -- Legacy ERB Lint configuration.
        --
        '.erb-lint.yml',

        --
        -- Ruby / Rails project boundaries.
        --
        'Gemfile',
        'Gemfile.lock',

        '.ruby-version',

        'config/application.rb',
        'config/environment.rb',

        'Rakefile',

        '.git',
    },

    stdin = false,

    stream = 'stdout',

    timeout = 60000,
}
