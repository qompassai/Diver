-- #################################################################
-- /qompassai/Diver/lua/linters/dialyzer.lua
-- Qompass AI Diver Native Dialyzer Linter
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
---@source https://www.erlang.org/docs/26/man/dialyzer.html
---@source https://www.erlang.org/docs/26/apps/dialyzer/dialyzer_chapter.html
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv
local ERROR = diagnostic.severity.ERROR
local WARN = diagnostic.severity.WARN
local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024
local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'dialyzer'

---@type string[]
local PLT_CANDIDATES = {
    '.dialyzer_plt',
    'dialyzer.plt',

    '_build/default/dialyzer.plt',
    '_build/dev/dialyzer.plt',
    '_build/test/dialyzer.plt',

    'priv/plts/dialyzer.plt',
}

---@type string[]
local INCLUDE_CANDIDATES = {
    'include',
    'src',
}

---@class DialyzerParsedDiagnostic
---@field filename string
---@field line integer
---@field column integer
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

    return floor(parsed)
end

---@param path string
---@return boolean
local function exists(path)
    return uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_directory(path)
    local stat = uv.fs_stat(path)

    return stat ~= nil and stat.type == 'directory'
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

    return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function normalize_message(value)
    assert(type(value) == 'string')

    value = strip_ansi(value)

    value = value:gsub('\r\n', '\n')

    value = value:gsub('\r', '\n')

    value = trim(value)

    if #value > MESSAGE_LENGTH_MAX then
        value = value:sub(1, MESSAGE_LENGTH_MAX) .. '\n[message truncated]'
    end

    return value
end

---@param root string
---@param candidates string[]
---@return string?
local function find_candidate(root, candidates)
    assert(root ~= '')

    for index = 1, #candidates do
        local candidate = fs.joinpath(root, candidates[index])

        if exists(candidate) then
            return fs.normalize(candidate)
        end
    end

    return nil
end

---@param root string
---@return string?
local function plt_file(root)
    local environment = vim.env.DIALYZER_PLT

    if type(environment) == 'string' and environment ~= '' and exists(environment) then
        return fs.normalize(environment)
    end

    return find_candidate(root, PLT_CANDIDATES)
end

---@param root string
---@return string[]
local function include_directories(root)
    assert(root ~= '')

    ---@type string[]
    local directories = {}

    for index = 1, #INCLUDE_CANDIDATES do
        local candidate = fs.joinpath(root, INCLUDE_CANDIDATES[index])

        if is_directory(candidate) then
            directories[#directories + 1] = fs.normalize(candidate)
        end
    end

    --
    -- Rebar3 dependencies commonly expose Erlang headers here.
    --
    local deps = fs.joinpath(root, '_build', 'default', 'lib')

    if is_directory(deps) then
        directories[#directories + 1] = fs.normalize(deps)
    end

    return directories
end

---@param path string
---@param root string
---@return string
local function normalize_path(path, root)
    assert(path ~= '')
    assert(root ~= '')

    if path:sub(1, 7) == 'file://' then
        local ok, filename = pcall(vim.uri_to_fname, path)

        if ok and type(filename) == 'string' and filename ~= '' then
            return fs.normalize(filename)
        end
    end

    if fs.is_absolute(path) then
        return fs.normalize(path)
    end

    return fs.normalize(fs.joinpath(root, path))
end

---@param candidate string
---@param filename string
---@param root string
---@return boolean
local function belongs_to_buffer(candidate, filename, root)
    assert(candidate ~= '')
    assert(filename ~= '')
    assert(root ~= '')

    return normalize_path(candidate, root) == filename
end

---@param line string
---@return DialyzerParsedDiagnostic?
local function parse_line(line)
    assert(type(line) == 'string')

    if line == '' or #line > LINE_LENGTH_MAX then
        return nil
    end

    line = strip_ansi(line)

    --
    -- With:
    --
    --   --fullpath
    --   --error_location column
    --   --no_indentation
    --
    -- Dialyzer warnings are formatted approximately as:
    --
    --   /path/foo.erl:12:7: The call ...
    --
    local filename, source_line, column, message = line:match('^(.+):(%d+):(%d+):%s*(.+)$')

    if filename ~= nil and source_line ~= nil and column ~= nil and message ~= nil then
        local parsed_line = integer(source_line, 0)

        local parsed_column = integer(column, 0)

        if parsed_line < 1 or parsed_column < 1 then
            return nil
        end

        message = normalize_message(message)

        if message == '' then
            return nil
        end

        return {
            filename = filename,
            line = parsed_line,
            column = parsed_column,
            message = message,
        }
    end

    --
    -- Some warnings may have only a line position.
    --
    filename, source_line, message = line:match('^(.+):(%d+):%s*(.+)$')

    if filename == nil or source_line == nil or message == nil then
        return nil
    end

    local parsed_line = integer(source_line, 0)

    if parsed_line < 1 then
        return nil
    end

    message = normalize_message(message)

    if message == '' then
        return nil
    end

    return {
        filename = filename,
        line = parsed_line,
        column = 1,
        message = message,
    }
end

---@param message string
---@return string
local function diagnostic_code(message)
    local lower = message:lower()

    if lower:find('contract', 1, true) then
        return 'contract'
    end

    if lower:find('will never return', 1, true) or lower:find('has no local return', 1, true) then
        return 'no-return'
    end

    if lower:find('will fail', 1, true) then
        return 'failing-call'
    end

    if lower:find('pattern', 1, true) and lower:find('never match', 1, true) then
        return 'no-match'
    end

    if lower:find('opaque', 1, true) then
        return 'opaque'
    end

    if lower:find('unused', 1, true) then
        return 'unused'
    end

    if lower:find('callback', 1, true) then
        return 'callback'
    end

    if lower:find('return', 1, true) then
        return 'return'
    end

    return 'success-typing'
end

---@param entry DialyzerParsedDiagnostic
---@param filename string
---@param root string
---@return vim.Diagnostic?
local function diagnostic_from_entry(entry, filename, root)
    if not belongs_to_buffer(entry.filename, filename, root) then
        return nil
    end

    --
    -- Dialyzer source locations are one-based.
    -- Neovim diagnostic locations are zero-based.
    --
    local lnum = max(entry.line - 1, 0)

    local col = max(entry.column - 1, 0)

    return {
        lnum = lnum,
        end_lnum = lnum,

        col = col,
        end_col = col + 1,

        message = entry.message,

        severity = WARN,

        source = SOURCE,

        code = diagnostic_code(entry.message),

        user_data = {
            analyzer = 'success-typing',
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

    assert(type(context) == 'table', 'dialyzer parser requires a LintContext')

    ---@cast context LintContext

    assert(context.filename ~= '')
    assert(context.root ~= '')

    assert(#output <= OUTPUT_LENGTH_MAX, 'dialyzer output exceeded maximum size')

    local filename = fs.normalize(context.filename)

    local root = fs.normalize(context.root)

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for line in output:gmatch('[^\r\n]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local raw = parse_line(line)

        if raw ~= nil then
            local entry = diagnostic_from_entry(raw, filename, root)

            if entry ~= nil then
                diagnostics[#diagnostics + 1] = entry
            end
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX)

    return diagnostics
end

---@param context LintContext
---@return string[]
local function args(context)
    assert(context.filename ~= '')
    assert(context.root ~= '')

    local root = fs.normalize(context.root)

    local argv = {
        --
        -- Analyze Erlang source instead of BEAM bytecode. This is the correct
        -- editor-facing mode because the current buffer may not yet have a
        -- corresponding compiled module.
        --
        '--src',

        --
        -- Make ownership checks deterministic even if Dialyzer changes cwd or
        -- encounters source files through include paths.
        --
        '--fullpath',

        --
        -- Request the most precise location available.
        --
        '--error_location',
        'column',

        --
        -- Keep each warning on one physical line so the native parser does not
        -- need to reconstruct Dialyzer's pretty-printed type expressions.
        --
        '--no_indentation',

        --
        -- Reduce progress chatter without suppressing actual warnings.
        --
        '--quiet',

        --
        -- Tiger warning extensions.
        --
        -- These are useful additional contract / correctness checks and are
        -- officially supported warning groups rather than the more experimental
        -- overspec/specdiff developer diagnostics.
        --
        '-Wunmatched_returns',
        '-Werror_handling',
        '-Wextra_return',
        '-Wmissing_return',

        context.filename,
    }

    local plt = plt_file(root)

    if plt ~= nil then
        --
        -- Explicitly select an existing project or environment PLT.
        --
        -- If none exists, Dialyzer retains its normal default PLT behavior.
        --
        table.insert(argv, #argv, '--plt')

        table.insert(argv, #argv, plt)
    end

    local includes = include_directories(root)

    for index = 1, #includes do
        table.insert(argv, #argv, '-I')

        table.insert(argv, #argv, includes[index])
    end

    return argv
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

return ---@type Linter
{
    automatic = false,

    cmd = 'dialyzer',

    args = args,

    append_fname = false,

    cwd = cwd,

    --
    -- Dialyzer's documented exit statuses are:
    --
    --   0 = no warnings
    --   1 = analysis/tool problem
    --   2 = warnings were emitted
    --
    -- Status 2 is therefore normal diagnostic-producing behavior.
    --
    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        --
        -- Rebar3.
        --
        'rebar.config',
        'rebar.config.script',
        'rebar.lock',

        --
        -- Erlang.mk.
        --
        'erlang.mk',

        --
        -- Mix projects can contain Erlang source and can use Dialyzer through
        -- their generated BEAM / PLT ecosystem.
        --
        'mix.exs',
        'mix.lock',

        --
        -- Explicit PLTs.
        --
        '.dialyzer_plt',
        'dialyzer.plt',

        --
        -- OTP application metadata.
        --
        'src',

        '.git',
    },

    stdin = false,

    --
    -- Formatted Dialyzer warnings are emitted on stdout.
    --
    stream = 'stdout',

    --
    -- Success typing and PLT consistency work can be substantially heavier than
    -- ordinary syntax linting.
    --
    timeout = 120000,
}
