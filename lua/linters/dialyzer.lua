-- #################################################################
-- /qompassai/Diver/lua/linters/dialyxer.lua
-- Qompass AI Diver Native Dialyzer + Dialyxir Linter
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################
---@source https://www.erlang.org/docs/26/man/dialyzer.html
---@source https://hexdocs.pm/dialyxir/readme.html

local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE_DIALYZER = 'dialyzer'
local SOURCE_DIALYXIR = 'dialyxir'

local DIALYZER_TIMEOUT_MS = 120000
local DIALYXIR_TIMEOUT_MS = 600000

local DIALYXIR_PLT_ROOT = 'priv/plts/dialyxir'
local DIALYXIR_CORE_PLT_PATH = 'priv/plts/dialyxir/core'
local DIALYXIR_PROJECT_PLT_PATH = 'priv/plts/dialyxir/project.plt'

---@type string[]
local DIRECT_PLT_CANDIDATES = {
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

---@type string[]
local TIGER_WARNING_FLAGS = {
    '-Wunmatched_returns',
    '-Werror_handling',
    '-Wextra_return',
    '-Wmissing_return',
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
local function direct_plt_file(root)
    local environment = vim.env.DIALYZER_PLT

    if type(environment) == 'string' and environment ~= '' and exists(environment) then
        return fs.normalize(environment)
    end

    return find_candidate(root, DIRECT_PLT_CANDIDATES)
end

---@param root string
---@return string[]
local function include_directories(root)
    assert(root ~= '')

    local directories = {}

    for index = 1, #INCLUDE_CANDIDATES do
        local candidate = fs.joinpath(root, INCLUDE_CANDIDATES[index])

        if is_directory(candidate) then
            directories[#directories + 1] = fs.normalize(candidate)
        end
    end

    local deps = fs.joinpath(root, '_build', 'default', 'lib')

    if is_directory(deps) then
        directories[#directories + 1] = fs.normalize(deps)
    end

    return directories
end

---@param root string
---@return boolean
local function is_mix_project(root)
    assert(root ~= '')

    return exists(fs.joinpath(root, 'mix.exs'))
end

---@param filename string
---@return boolean
local function is_elixir_source(filename)
    return filename:sub(-3) == '.ex' or filename:sub(-4) == '.exs'
end

---@param filename string
---@return boolean
local function is_erlang_source(filename)
    return filename:sub(-4) == '.erl'
end

---@param context LintContext
---@return boolean
local function use_dialyxir(context)
    assert(context.filename ~= '')
    assert(context.root ~= '')

    return is_mix_project(context.root) and is_elixir_source(context.filename)
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

    local filename, source_line, column, message =
        line:match('^(.+):(%d+):(%d+):%s*(.+)$')

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

    if lower:find('will never return', 1, true)
        or lower:find('has no local return', 1, true)
    then
        return 'no-return'
    end

    if lower:find('will fail', 1, true) then
        return 'failing-call'
    end

    if lower:find('pattern', 1, true)
        and lower:find('never match', 1, true)
    then
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
---@param source string
---@param analyzer string
---@return vim.Diagnostic?
local function diagnostic_from_entry(entry, filename, root, source, analyzer)
    if not belongs_to_buffer(entry.filename, filename, root) then
        return nil
    end

    local lnum = max(entry.line - 1, 0)
    local col = max(entry.column - 1, 0)

    return {
        lnum = lnum,
        end_lnum = lnum,
        col = col,
        end_col = col + 1,
        message = entry.message,
        severity = WARN,
        source = source,
        code = diagnostic_code(entry.message),
        user_data = {
            analyzer = analyzer,
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

    local dialyxir = use_dialyxir(context)
    local source = dialyxir and SOURCE_DIALYXIR or SOURCE_DIALYZER
    local analyzer = dialyxir and 'dialyxir' or 'success-typing'

    local diagnostics = {}

    for line in output:gmatch('[^
]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local raw = parse_line(line)

        if raw ~= nil then
            local entry = diagnostic_from_entry(raw, filename, root, source, analyzer)

            if entry ~= nil then
                diagnostics[#diagnostics + 1] = entry
            end
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX)

    return diagnostics
end

---@param argv string[]
---@param flags string[]
local function append_flags(argv, flags)
    for index = 1, #flags do
        argv[#argv + 1] = flags[index]
    end
end

---@param context LintContext
---@return string[]
local function direct_dialyzer_args(context)
    assert(context.filename ~= '')
    assert(context.root ~= '')

    local root = fs.normalize(context.root)

    local argv = {
        '--src',
        '--fullpath',
        '--error_location',
        'column',
        '--no_indentation',
        '--quiet',
    }

    append_flags(argv, TIGER_WARNING_FLAGS)

    local plt = direct_plt_file(root)

    if plt ~= nil then
        argv[#argv + 1] = '--plt'
        argv[#argv + 1] = plt
    end

    local includes = include_directories(root)

    for index = 1, #includes do
        argv[#argv + 1] = '-I'
        argv[#argv + 1] = includes[index]
    end

    argv[#argv + 1] = context.filename

    return argv
end

---@param root string
---@return string[]
local function dialyxir_args(root)
    assert(root ~= '')

    --
    -- Dialyxir's configuration is deliberately supplied only on this
    -- invocation. No config/config.exs or project-local Dialyxir settings
    -- are required for the command itself.
    --
    return {
        'dialyzer',

        --
        -- Project behavior.
        --
        '--no-compile',
        '--no-check',

        --
        -- Preserve Dialyzer-compatible locations for parse_line().
        --
        '--format',
        'dialyzer',

        --
        -- Explicit PLT ownership and stable repository-local paths.
        --
        '--plt-core-path',
        fs.joinpath(root, DIALYXIR_CORE_PLT_PATH),

        '--plt-local-path',
        fs.joinpath(root, DIALYXIR_PROJECT_PLT_PATH),

        --
        -- Include the direct application dependency tree in the project PLT.
        --
        '--plt-add-deps',
        'app_tree',

        --
        -- Make common Mix/runtime apps available when a project depends on
        -- them. Missing apps only matter when the project actually uses them.
        --
        '--plt-add-apps',
        'mix',
        '--plt-add-apps',
        'ex_unit',

        --
        -- Tiger warning policy. These are forwarded to Dialyzer.
        --
        '--flags',
        '-Wunmatched_returns',
        '-Werror_handling',
        '-Wextra_return',
        '-Wmissing_return',
    }
end

---@param context LintContext
---@return string
local function cmd(context)
    if use_dialyxir(context) then
        return 'mix'
    end

    return 'dialyzer'
end

---@param context LintContext
---@return string[]
local function args(context)
    assert(context.filename ~= '')
    assert(context.root ~= '')

    if use_dialyxir(context) then
        return dialyxir_args(fs.normalize(context.root))
    end

    return direct_dialyzer_args(context)
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

---@param context LintContext
---@return integer
local function timeout(context)
    if use_dialyxir(context) then
        return DIALYXIR_TIMEOUT_MS
    end

    return DIALYZER_TIMEOUT_MS
end

return ---@type Linter
{
    automatic = false,

    cmd = cmd,

    args = args,

    append_fname = false,

    cwd = cwd,

    ignore_exitcode = true,

    parser = parse,

    root_markers = {
        'rebar.config',
        'rebar.config.script',
        'rebar.lock',
        'erlang.mk',
        'mix.exs',
        'mix.lock',
        '.dialyzer_plt',
        'dialyzer.plt',
        'src',
        '.git',
    },

    stdin = false,

    stream = 'stdout',

    timeout = timeout,
}