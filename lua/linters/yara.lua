-- #################################################################
-- /qompassai/Diver/lua/linters/yara.lua
-- Native YARA compiler linter
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/VirusTotal/yara/tree/84b0e3cc0e42f8f8e6b84d19c97ec3ac6ff8aee8
---@source https://yara.readthedocs.io/en/stable/commandline.html
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local TOOLING = {
    executable = 'yarac',
    max_strings_per_rule = 10000,
    output_path = '/dev/null',
    timeout_ms = 30000,
}
local ROOT_MARKERS = {
    '.git',
    '.hg',
    '.svn',
}
local LIMITS = {
    diagnostics = 1024,
    lines = 8192,
    message_bytes = 4096,
    output_bytes = 4 * 1024 * 1024,
    source_line = 2147483647,
}
local ARGUMENTS = {
    '--strict-escape',
    '--fail-on-warnings',
    '--max-strings-per-rule=' .. tostring(TOOLING.max_strings_per_rule),
    '-',
    TOOLING.output_path,
}

local CLI_CHOICES = {
    atom_quality_table = false,
    defines = {},
    defines_max = 32,
    fail_on_warnings = true,
    help = false,
    max_strings_per_rule = TOOLING.max_strings_per_rule,
    namespace = false,
    no_warnings = false,
    output_file = TOOLING.output_path,
    source_files = {
        '<stdin>',
    },
    strict_escape = true,
    version = false,
}

---@class YaraCompilerMessage
---@field level 'error'|'warning'
---@field line integer
---@field message string
---@field path? string
---@field rule? string

---@class YaraDefinition:Linter
---@field cli_choices table<string, any>

---@type YaraDefinition
local M = {
    cli_choices = vim.deepcopy(CLI_CHOICES),
    cmd = TOOLING.executable,
}

local function validate_configuration()
    assert(TOOLING.executable == 'yarac')
    assert(TOOLING.max_strings_per_rule >= 1)
    assert(TOOLING.max_strings_per_rule <= 1000000)
    assert(TOOLING.output_path == '/dev/null')
    assert(TOOLING.timeout_ms >= 1000)
    assert(TOOLING.timeout_ms <= 300000)
    assert(LIMITS.diagnostics >= 2)
    assert(LIMITS.lines >= LIMITS.diagnostics)
    assert(ARGUMENTS[#ARGUMENTS - 1] == '-')
    assert(ARGUMENTS[#ARGUMENTS] == TOOLING.output_path)

    local joined = table.concat(ARGUMENTS, '\0')

    assert(joined:find('%-%-strict%-escape') ~= nil)
    assert(joined:find('%-%-fail%-on%-warnings') ~= nil)
    assert(joined:find('%-%-no%-warnings') == nil)
    assert(#CLI_CHOICES.defines <= CLI_CHOICES.defines_max)
end

validate_configuration()

---@return string
local function process_directory()
    local cwd = uv.cwd()

    if type(cwd) == 'string' and cwd ~= '' then
        return cwd
    end

    return '.'
end

---@param context LintContext
---@return string
local function working_directory(context)
    assert(type(context.filename) == 'string')

    local parent = fs.dirname(context.filename)

    if type(parent) == 'string' and parent ~= '' then
        return parent
    end

    return process_directory()
end

---@param value string
---@return string
local function clean(value)
    local message = vim.trim(value:gsub('[%z\1-\31\127]', ' '))

    if #message <= LIMITS.message_bytes then
        return message
    end

    local last = LIMITS.message_bytes - 3

    while last > 0 do
        local byte = message:byte(last + 1)

        if byte == nil or byte < 128 or byte >= 192 then
            break
        end

        last = last - 1
    end

    return message:sub(1, last) .. '...'
end

---@param value string
---@param fallback integer
---@return integer
local function integer(value, fallback)
    assert(fallback >= 0)

    local parsed = tonumber(value)

    if parsed == nil or parsed < 1 or parsed > LIMITS.source_line then
        return fallback
    end

    if parsed ~= math.floor(parsed) then
        return fallback
    end

    local result = math.floor(parsed)
    ---@cast result integer
    return result
end

---@param path string
---@return boolean
local function is_absolute(path)
    assert(path ~= '')

    return path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil or path:sub(1, 2) == '\\\\'
end

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
    assert(path ~= '')
    assert(cwd ~= '')

    if not is_absolute(path) then
        path = fs.joinpath(cwd, path)
    end

    local normalized = fs.normalize(path)

    if type(normalized) == 'string' and normalized ~= '' then
        path = normalized
    end

    return uv.fs_realpath(path) or path
end

---@param path string
---@param context LintContext
---@return boolean
local function belongs_to_buffer(path, context)
    if path == '-' or path == '<stdin>' or path == 'stdin' then
        return true
    end

    local cwd = working_directory(context)
    local candidate = canonical(path, cwd)
    local filename = canonical(context.filename, cwd)

    return candidate == filename
end

---@param line string
---@return YaraCompilerMessage?
local function parse_compiler_line(line)
    assert(#line <= LIMITS.message_bytes * 2)

    local level, rule, path, line_number, message =
        line:match('^(%a+):%s+rule%s+"([^"]+)"%s+in%s+(.+)%((%d+)%)%:%s*(.+)$')

    if level == nil then
        level, path, line_number, message = line:match('^(%a+):%s+(.+)%((%d+)%)%:%s*(.+)$')
    end

    if level == 'error' or level == 'warning' then
        assert(path ~= nil)
        assert(line_number ~= nil)
        assert(message ~= nil)

        return {
            level = level,
            line = integer(line_number, 1),
            message = clean(message),
            path = path,
            rule = rule,
        }
    end

    local global_level, global_message = line:match('^(%a+):%s+(.+)$')

    if global_level ~= 'error' and global_level ~= 'warning' then
        return nil
    end

    assert(global_message ~= nil)

    return {
        level = global_level,
        line = 1,
        message = clean(global_message),
    }
end

---@param context LintContext
---@param line_number integer
---@return integer
local function bounded_row(context, line_number)
    local line_count = api.nvim_buf_line_count(context.bufnr)

    if line_count < 1 then
        line_count = 1
    end

    local row = line_number - 1

    if row < 0 then
        return 0
    end

    if row >= line_count then
        return line_count - 1
    end

    return row
end

---@param context LintContext
---@param code string
---@param message string
---@return vim.Diagnostic
local function status(context, code, message)
    return {
        bufnr = context.bufnr,
        lnum = 0,
        end_lnum = 0,
        col = 0,
        end_col = 0,
        severity = diagnostic.severity.ERROR,
        source = 'yarac',
        code = code,
        message = clean(message),
    }
end

---@param context LintContext
---@param item YaraCompilerMessage
---@return vim.Diagnostic
local function diagnostic_for(context, item)
    local row = bounded_row(context, item.line)
    local message = item.message
    local code = item.rule or ('YARA_' .. item.level:upper())

    if item.rule ~= nil then
        message = ('rule "%s": %s'):format(item.rule, message)
    end

    if item.path ~= nil and not belongs_to_buffer(item.path, context) then
        row = 0
        code = 'YARA_INCLUDED_FILE'
        message = ('included file %s:%d: %s'):format(item.path, item.line, message)
    end

    return {
        bufnr = context.bufnr,
        lnum = row,
        end_lnum = row,
        col = 0,
        end_col = 1,
        severity = item.level == 'warning' and diagnostic.severity.WARN or diagnostic.severity.ERROR,
        source = 'yarac',
        code = code,
        message = clean(message),
        user_data = {
            origin = item.path,
            rule = item.rule,
        },
    }
end

---@param diagnostics vim.Diagnostic.Set[]
---@param item vim.Diagnostic
---@return boolean
local function push(diagnostics, item)
    if #diagnostics >= LIMITS.diagnostics - 1 then
        return false
    end

    diagnostics[#diagnostics + 1] = item
    return true
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, context)
    assert(type(output) == 'string')
    assert(type(context) == 'table', 'yarac parser requires a LintContext')
    assert(type(context.bufnr) == 'number')
    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')

    if output == '' then
        return {}
    end

    if #output > LIMITS.output_bytes then
        return {
            status(context, 'YARA_OUTPUT_LIMIT', 'yarac output exceeded the parser limit'),
        }
    end

    ---@type vim.Diagnostic.Set[]
    local diagnostics = {}
    local line_count = 0
    local truncated = false

    for line in output:gmatch('[^\r\n]+') do
        line_count = line_count + 1

        if line_count > LIMITS.lines or #line > LIMITS.message_bytes * 2 then
            truncated = true
            break
        end

        local item = parse_compiler_line(line)
        local parsed = item ~= nil and diagnostic_for(context, item) or status(context, 'YARA_UNPARSED_OUTPUT', line)

        if not push(diagnostics, parsed) then
            truncated = true
            break
        end
    end

    if truncated then
        diagnostics[#diagnostics + 1] = status(context, 'YARA_DIAGNOSTIC_LIMIT', 'additional yarac output was omitted')
    end

    assert(#diagnostics <= LIMITS.diagnostics)
    return diagnostics
end

M.args = vim.deepcopy(ARGUMENTS)
M.append_fname = false
M.automatic = true
M.cwd = working_directory
M.env = {
    LANG = 'C',
    LC_ALL = 'C',
    NO_COLOR = '1',
}
M.errorformat = nil
M.exit_codes = {
    0,
    1,
}
M.ignore_exitcode = false
M.parser = parse
M.root_markers = vim.deepcopy(ROOT_MARKERS)
M.stdin = true
M.stream = 'stderr'
M.timeout = TOOLING.timeout_ms

return M
