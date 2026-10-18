-- /qompassai/Diver/lua/linters/alex.lua
-- Qompass AI Diver Native Alex Linter
---@module 'linters.alex'
---@source https://github.com/get-alex/alex
---@source https://alexjs.com

local diagnostic = vim.diagnostic
local fn = vim.fn
local fs = vim.fs
local uv = vim.uv

local ERROR = diagnostic.severity.ERROR
local HINT = diagnostic.severity.HINT
local INFO = diagnostic.severity.INFO
local WARN = diagnostic.severity.WARN

local DIAGNOSTICS_MAX = 4096
local LINE_LENGTH_MAX = 64 * 1024
local MESSAGE_LENGTH_MAX = 16 * 1024
local OUTPUT_LENGTH_MAX = 16 * 1024 * 1024

local floor = math.floor
local max = math.max
local tonumber = tonumber
local type = type

local SOURCE = 'alex'

---@type table<string, integer>
local SEVERITIES = {
    error = ERROR,
    fatal = ERROR,
    hint = HINT,
    info = INFO,
    information = INFO,
    note = HINT,
    warn = WARN,
    warning = WARN,
}

---@type table<string, boolean>
local HTML_FILETYPES = {
    html = true,
}

---@type table<string, boolean>
local MDX_FILETYPES = {
    mdx = true,
}

---@type table<string, boolean>
local TEXT_FILETYPES = {
    text = true,
}

---@class AlexParsedDiagnostic
---@field start_line integer
---@field start_column integer
---@field end_line integer
---@field end_column integer
---@field severity string
---@field message string
---@field code? string
---@field origin? string

---@param context LintContext
---@return string[]
local function args(context)
    assert(context.filename ~= '')
    assert(context.root ~= '')

    local argv = {}

    local filetype = context.filetype:lower()

    --
    -- Alex defaults to Markdown parsing.
    --
    -- Explicitly select only the alternate parsers where the Neovim filetype
    -- proves that another input grammar is required.
    --
    if HTML_FILETYPES[filetype] then
        argv[#argv + 1] = '--html'
    elseif MDX_FILETYPES[filetype] then
        argv[#argv + 1] = '--mdx'
    elseif TEXT_FILETYPES[filetype] then
        argv[#argv + 1] = '--text'
    end

    --
    -- Supply exactly one file. When Alex receives no explicit input, it searches
    -- the current directory plus doc/ and docs/, which is undesirable during an
    -- interactive editor lint operation.
    --
    argv[#argv + 1] = context.filename

    return argv
end

---Resolve the alexjs executable.
---
---`alex` names two unrelated tools that both install an `alex` binary:
---alexjs (get-alex/alex), the prose linter this adapter targets, and the
---Haskell lexer generator. On primo /usr/bin/alex is the Haskell tool, so
---a bare `alex` invocation runs the wrong program entirely.
---
---Project-local npm installs are unambiguous — node_modules/.bin never
---holds the Haskell tool — so prefer them. Otherwise invoke the npm-global
---package's entry point directly: cli.js is an executable
---`#!/usr/bin/env node` script that no PATH collision can shadow, located
---under the lib/node_modules of the prefix that owns the `npm` binary.
---
---The bare name remains only as a last resort for machines where PATH
---`alex` really is alexjs.
---
---@param context LintContext
---@return string
local function command(context)
    assert(context.root ~= '')

    local local_command = fs.joinpath(context.root, 'node_modules', '.bin', 'alex')

    if fn.executable(local_command) == 1 then
        return local_command
    end

    local npm = fn.exepath('npm')

    if npm ~= '' then
        local prefix = fs.dirname(fs.dirname(npm))

        if prefix ~= nil then
            local global_command = fs.joinpath(prefix, 'lib', 'node_modules', 'alex', 'cli.js')

            if uv.fs_stat(global_command) ~= nil then
                return global_command
            end
        end
    end

    return 'alex'
end

---@param context LintContext
---@return string
local function cwd(context)
    assert(context.root ~= '')

    return fs.normalize(context.root)
end

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

---@param value string
---@return boolean
local function looks_like_rule(value)
    if value == '' then
        return false
    end

    return value:match('^[%w][%w_%-%.:/]*$') ~= nil
end

---@param value string|nil
---@return integer
local function severity(value)
    if type(value) ~= 'string' then
        return WARN
    end

    return SEVERITIES[value:lower()] or WARN
end

---@param entry AlexParsedDiagnostic
---@return vim.Diagnostic.Set
local function diagnostic_from_entry(entry)
    --
    -- VFile source positions are one-based.
    -- Neovim diagnostic positions are zero-based.
    --
    local lnum = max(entry.start_line - 1, 0)

    local col = max(entry.start_column - 1, 0)

    local end_lnum = max(entry.end_line - 1, lnum)

    --
    -- VFile end positions are exclusive. Converting the one-based VFile column
    -- to Neovim's zero-based exclusive column therefore requires -1.
    --
    local minimum_end_col = end_lnum == lnum and col + 1 or 0

    local end_col = max(entry.end_column - 1, minimum_end_col)

    return {
        code = entry.code,
        col = col,
        end_col = end_col,
        end_lnum = end_lnum,
        lnum = lnum,
        message = entry.message,
        severity = severity(entry.severity),
        source = SOURCE,
        user_data = {
            alex_severity = entry.severity,
            origin = entry.origin,
            rule = entry.code,
        },
    }
end

---@param value string
---@return string
local function strip_ansi(value)
    assert(type(value) == 'string')

    return (value:gsub('\27%[[%d;?]*[ -/]*[@-~]', ''))
end

---@param value string
---@return string
local function trim(value)
    assert(type(value) == 'string')

    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

---@param value string
---@return boolean
local function is_summary(value)
    value = trim(strip_ansi(value))

    if value == '' then
        return true
    end

    if value:find('no issues found', 1, true) ~= nil then
        return true
    end

    if value:match('^⚠%s*%d+%s+warnings?%s*$') ~= nil then
        return true
    end

    if value:match('^%d+%s+warnings?%s*$') ~= nil then
        return true
    end

    if value:match('^%d+%s+errors?%s*$') ~= nil then
        return true
    end

    return false
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

---@param line string
---@return AlexParsedDiagnostic?
local function parse_line(line)
    assert(type(line) == 'string')

    if line == '' or #line > LINE_LENGTH_MAX or is_summary(line) then
        return nil
    end

    line = strip_ansi(line)

    --
    -- Current Alex / vfile-reporter output:
    --
    --   1:15-1:18  warning  `pop` may be insensitive ...  dad-mom  retext-equality
    --
    -- Diagnostic positions are VFile positions:
    --
    --   start-line:start-column-end-line:end-column
    --
    local start_line, start_column, end_line, end_column, level, remainder =
        line:match('^%s*(%d+):(%d+)%-(%d+):(%d+)' .. '%s+([%a]+)%s+(.+)%s*$')

    if
        start_line == nil
        or start_column == nil
        or end_line == nil
        or end_column == nil
        or level == nil
        or remainder == nil
    then
        return nil
    end

    local parsed_start_line = integer(start_line, 0)

    local parsed_start_column = integer(start_column, 0)

    local parsed_end_line = integer(end_line, 0)

    local parsed_end_column = integer(end_column, 0)

    if parsed_start_line < 1 or parsed_start_column < 1 or parsed_end_line < 1 or parsed_end_column < 1 then
        return nil
    end

    if parsed_end_line < parsed_start_line then
        return nil
    end

    if parsed_end_line == parsed_start_line and parsed_end_column < parsed_start_column then
        return nil
    end

    --
    -- vfile-reporter renders the message, rule identifier, and plugin/source as
    -- separate aligned columns using runs of at least two spaces:
    --
    --   <message>  <rule>  <plugin>
    --
    -- Parse from the right so ordinary spaces inside the prose message remain
    -- untouched.
    --
    local message, code, origin = remainder:match('^(.-)%s%s+([^%s]+)%s%s+([^%s]+)%s*$')

    if message == nil or code == nil or origin == nil then
        --
        -- Preserve the diagnostic even if a future reporter version omits the
        -- optional rule / source columns.
        --
        message = remainder
        code = nil
        origin = nil
    else
        if not looks_like_rule(code) then
            code = nil
        end

        if not looks_like_rule(origin) then
            origin = nil
        end
    end

    message = normalize_message(message)

    if message == '' then
        return nil
    end

    return {
        code = code,
        end_column = parsed_end_column,
        end_line = parsed_end_line,
        message = message,
        origin = origin,
        severity = level,
        start_column = parsed_start_column,
        start_line = parsed_start_line,
    }
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    assert(type(context) == 'table', 'alex parser requires a LintContext')

    ---@cast context LintContext

    assert(context.filename ~= '')
    assert(context.root ~= '')

    assert(#output <= OUTPUT_LENGTH_MAX, 'alex output exceeded maximum size')

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}

    for line in output:gmatch('[^\r\n]+') do
        if #diagnostics >= DIAGNOSTICS_MAX then
            break
        end

        local entry = parse_line(line)

        if entry ~= nil then
            diagnostics[#diagnostics + 1] = diagnostic_from_entry(entry)
        end
    end

    assert(#diagnostics <= DIAGNOSTICS_MAX)

    return diagnostics
end

return ---@type Linter
{
    append_fname = false,
    args = args,
    automatic = false,
    cmd = command,
    cwd = cwd,
    --
    -- Alex invokes unified-engine with frail=true, so warnings legitimately
    -- cause a nonzero process exit. The diagnostic output remains valid.
    --
    ignore_exitcode = true,
    parser = parse,
    root_markers = {
        '.alexrc',
        '.alexrc.json',
        '.alexrc.yaml',
        '.alexrc.yml',
        '.alexrc.js',
        '.alexrc.cjs',

        '.alexignore',

        'package.json',

        '.git',
    },
    stdin = false,
    --
    -- Alex's vfile reporter is emitted through the engine's diagnostic stream.
    --
    stream = 'stderr',
    timeout = 30000,
}
