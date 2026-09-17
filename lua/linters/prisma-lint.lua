-- #################################################################
-- /qompassai/Diver/lua/linters/prisma_lint.lua
-- Native prisma-lint schema linter -- Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/loop-payments/prisma-lint/tree/7aa8ad22490e4bf599594e004ccf335a595240f3
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local json = vim.json
local uv = vim.uv

local TOOLING = {
    executable = 'prisma-lint',
    timeout_ms = 30000,
}
local LIMITS = {
    diagnostics = 512,
    message_bytes = 4096,
    output_bytes = 16 * 1024 * 1024,
    violations = 511,
}

-- Complete asynchronous cosmiconfig search-place inventory for the
-- "prismalint" module, followed by project-boundary fallbacks.
local ROOT_MARKERS = {
    'package.json',
    '.prismalintrc',
    '.prismalintrc.json',
    '.prismalintrc.yaml',
    '.prismalintrc.yml',
    '.prismalintrc.js',
    '.prismalintrc.ts',
    '.prismalintrc.mjs',
    '.prismalintrc.cjs',
    '.config/prismalintrc',
    '.config/prismalintrc.json',
    '.config/prismalintrc.yaml',
    '.config/prismalintrc.yml',
    '.config/prismalintrc.js',
    '.config/prismalintrc.ts',
    '.config/prismalintrc.mjs',
    '.config/prismalintrc.cjs',
    'prismalint.config.js',
    'prismalint.config.ts',
    'prismalint.config.mjs',
    'prismalint.config.cjs',
    'prisma.config.ts',
    '.config/prisma.ts',
    '.git',
}

local AVAILABLE_RULES = {
    'ban-unbounded-string-type',
    'enum-name-pascal-case',
    'enum-value-case',
    'enum-value-snake-case',
    'field-name-camel-case',
    'field-name-grammatical-number',
    'field-name-mapping-snake-case',
    'field-order',
    'forbid-field',
    'forbid-required-ignored-field',
    'model-name-grammatical-number',
    'model-name-mapping-snake-case',
    'model-name-pascal-case',
    'model-name-prefix',
    'require-default-empty-arrays',
    'require-field',
    'require-field-index',
    'require-field-type',
}
local DEPRECATED_RULES = {
    ['enum-value-snake-case'] = 'enum-value-case',
}

-- Complete prisma-lint 0.13.1 CLI choice inventory. The linter passes an
-- explicit current-file path, so Prisma's default/configured schema path is
-- deliberately bypassed while cosmiconfig rule discovery remains enabled.
local CLI_CHOICES = {
    color = false,
    config = false,
    config_discovery = 'cosmiconfig',
    default_schema_path = false,
    help = false,
    output_format = 'json',
    output_formats = {
        contextual = false,
        filepath = false,
        json = true,
        none = false,
        simple = false,
    },
    paths = {
        'current-buffer-filename',
    },
    quiet = true,
    version = false,
}

---@class PrismaLintLocation
---@field startLine number
---@field startColumn number
---@field endLine number
---@field endColumn number

---@class PrismaLintViolation
---@field ruleName string
---@field message string
---@field fileName string
---@field location PrismaLintLocation

---@class PrismaLintReport
---@field violations PrismaLintViolation[]

---@class PrismaLintDefinition:Linter
---@field available_rules string[]
---@field cli_choices table<string, any>
---@field deprecated_rules table<string, string>
---@field rule_levels string[]

local function validate_configuration()
    assert(#AVAILABLE_RULES == 18)
    assert(#ROOT_MARKERS == 24)
    assert(LIMITS.diagnostics == LIMITS.violations + 1)
    assert(LIMITS.message_bytes >= 256)
    assert(LIMITS.output_bytes >= LIMITS.message_bytes)
    assert(TOOLING.timeout_ms >= 1000)
    assert(TOOLING.timeout_ms <= 300000)
    assert(CLI_CHOICES.color == false)
    assert(CLI_CHOICES.config == false)
    assert(CLI_CHOICES.output_format == 'json')
    assert(CLI_CHOICES.quiet == true)

    local seen = {}

    for _, name in ipairs(AVAILABLE_RULES) do
        assert(type(name) == 'string')
        assert(name ~= '')
        assert(seen[name] == nil)
        seen[name] = true
    end

    for deprecated, replacement in pairs(DEPRECATED_RULES) do
        assert(seen[deprecated] == true)
        assert(seen[replacement] == true)
    end
end

validate_configuration()

---@param filename string
---@return string
local function root_for_path(filename)
    return fs.root(filename, ROOT_MARKERS) or fs.dirname(filename) or uv.cwd() or '.'
end

---@param context LintContext
---@return string
local function root(context)
    assert(type(context) == 'table')
    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')

    return root_for_path(context.filename)
end

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
    assert(type(path) == 'string')
    assert(type(cwd) == 'string')

    local absolute = path:sub(1, 1) == '/' or path:match('^%a:[/\\]') ~= nil

    if not absolute then
        path = fs.joinpath(cwd, path)
    end

    path = fs.normalize(path)

    return uv.fs_realpath(path) or path
end

---@param context LintContext
---@return string[]
local function arguments(context)
    assert(type(context) == 'table')
    assert(type(context.filename) == 'string')
    assert(context.filename ~= '')

    return {
        '--output-format=json',
        '--no-color',
        '--quiet',
        canonical(context.filename, root(context)),
    }
end

---@param value string
---@return string
local function clean(value)
    assert(type(value) == 'string')

    local message = vim.trim(value:gsub('[%z\1-\31\127]', ' '))

    if #message <= LIMITS.message_bytes then
        return message
    end

    local last = LIMITS.message_bytes - 3

    while last > 0 and message:byte(last) >= 128 and message:byte(last) < 192 do
        last = last - 1
    end

    return message:sub(1, last) .. '...'
end

---@param value any
---@return integer?
local function integer(value)
    if type(value) ~= 'number' or value % 1 ~= 0 then
        return nil
    end

    ---@cast value integer
    return value
end

---@param bufnr integer
---@param row integer
---@return string
local function buffer_line(bufnr, row)
    local lines = api.nvim_buf_get_lines(bufnr, row, row + 1, false)

    return lines[1] or ''
end

---@param context LintContext
---@param location PrismaLintLocation
---@return integer, integer, integer, integer
local function diagnostic_range(context, location)
    local start_line = integer(location.startLine)
    local start_column = integer(location.startColumn)
    local end_line = integer(location.endLine)
    local end_column = integer(location.endColumn)

    assert(start_line ~= nil and start_line >= 1)
    assert(start_column ~= nil and start_column >= 1)
    assert(end_line ~= nil and end_line >= start_line)
    assert(end_column ~= nil and end_column >= 1)

    local line_count = math.max(api.nvim_buf_line_count(context.bufnr), 1)
    local lnum = math.min(start_line - 1, line_count - 1)
    local end_lnum = math.min(end_line - 1, line_count - 1)
    local col = math.min(start_column - 1, #buffer_line(context.bufnr, lnum))
    -- prisma-lint locations use inclusive, one-based end columns; Neovim uses
    -- exclusive, zero-based end columns. The numeric end column is therefore
    -- already the correct Neovim value after clamping.
    local end_col = math.min(end_column, #buffer_line(context.bufnr, end_lnum))

    if end_lnum == lnum then
        end_col = math.max(end_col, col)
    end

    return lnum, col, end_lnum, end_col
end

---@param message string
---@param context LintContext
---@return vim.Diagnostic
local function status_diagnostic(message, context)
    return {
        bufnr = context.bufnr,
        col = 0,
        end_col = 0,
        end_lnum = 0,
        lnum = 0,
        message = clean(message),
        severity = diagnostic.severity.ERROR,
        source = 'prisma-lint',
    }
end

---@param violation PrismaLintViolation
---@param context LintContext
---@param cwd string
---@param current string
---@return vim.Diagnostic?
local function convert_violation(violation, context, cwd, current)
    if
        type(violation.ruleName) ~= 'string'
        or type(violation.message) ~= 'string'
        or type(violation.fileName) ~= 'string'
        or type(violation.location) ~= 'table'
    then
        return nil
    end

    local reported = canonical(violation.fileName, cwd)

    if reported ~= current then
        return nil
    end

    local ok, lnum, col, end_lnum, end_col = pcall(diagnostic_range, context, violation.location)

    if not ok then
        return nil
    end

    return {
        bufnr = context.bufnr,
        code = violation.ruleName,
        col = col,
        end_col = end_col,
        end_lnum = end_lnum,
        lnum = lnum,
        message = clean(violation.message),
        severity = diagnostic.severity.ERROR,
        source = 'prisma-lint',
        user_data = {
            file = violation.fileName,
            rule = violation.ruleName,
        },
    }
end

---@param report PrismaLintReport
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_report(report, context)
    local diagnostics = {}
    local rejected = 0
    local cwd = root(context)
    local current = canonical(context.filename, cwd)

    for index, violation in ipairs(report.violations) do
        if index > LIMITS.violations then
            break
        end

        local item = convert_violation(violation, context, cwd, current)

        if item ~= nil then
            diagnostics[#diagnostics + 1] = item
        else
            rejected = rejected + 1
        end
    end

    if #report.violations > LIMITS.violations then
        diagnostics[#diagnostics + 1] = status_diagnostic(
            'prisma-lint diagnostics were truncated at ' .. LIMITS.violations,
            context
        )
    elseif rejected > 0 then
        diagnostics[#diagnostics + 1] = status_diagnostic(
            ('prisma-lint returned %d malformed or foreign-file violation(s)'):format(rejected),
            context
        )
    end

    assert(#diagnostics <= LIMITS.diagnostics)

    return diagnostics
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse_output(output, context)
    assert(type(output) == 'string')
    assert(type(context) == 'table')
    assert(type(context.bufnr) == 'number')
    assert(type(context.filename) == 'string')

    if output == '' then
        return {}
    end

    if #output > LIMITS.output_bytes then
        return { status_diagnostic('prisma-lint output exceeded the 16 MiB safety limit', context) }
    end

    local ok, report = pcall(json.decode, output)

    if
        not ok
        or type(report) ~= 'table'
        or type(report.violations) ~= 'table'
        or not vim.islist(report.violations)
    then
        return {
            status_diagnostic('prisma-lint returned non-JSON output: ' .. output, context),
        }
    end

    ---@cast report PrismaLintReport
    return parse_report(report, context)
end

---@type PrismaLintDefinition
local M = {
    append_fname = false,
    args = arguments,
    automatic = true,
    available_rules = vim.deepcopy(AVAILABLE_RULES),
    cli_choices = vim.deepcopy(CLI_CHOICES),
    cmd = TOOLING.executable,
    cwd = root,
    deprecated_rules = vim.deepcopy(DEPRECATED_RULES),
    env = {
        FORCE_COLOR = '0',
        LANG = 'C',
        LC_ALL = 'C',
        NO_COLOR = '1',
    },
    errorformat = nil,
    exit_codes = {
        0,
        1,
    },
    ignore_exitcode = false,
    parser = parse_output,
    root_markers = vim.deepcopy(ROOT_MARKERS),
    rule_levels = {
        'error',
        'off',
    },
    stdin = false,
    stream = 'stderr',
    timeout = TOOLING.timeout_ms,
}

return M