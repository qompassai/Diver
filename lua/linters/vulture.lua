-- #################################################################
-- /qompassai/Diver/lua/linters/vulture.lua
-- Native Vulture Python dead-code linter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/jendrikseipp/vulture/tree/b0f67ba0044693aa9ec0d38fe460590facc98004
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local TOOLING = {
    config_path = '/dev/null',
    executable = 'vulture',
    min_confidence = 0,
    timeout_ms = 30000,
}
local ROOT_MARKERS = {
    'pyproject.toml',
    'setup.cfg',
    'tox.ini',
    'setup.py',
    'requirements.txt',
    '.git',
}
local LIMITS = {
    diagnostics = 4096,
    line_bytes = 64 * 1024,
    lines = 65536,
    message_bytes = 4096,
    output_bytes = 16 * 1024 * 1024,
}
local CODES = {
    attribute = 'V101',
    class = 'V102',
    ['function'] = 'V103',
    import = 'V104',
    method = 'V105',
    property = 'V106',
    unreachable_code = 'V201',
    variable = 'V107',
}

local CLI_CHOICES = {
    config = TOOLING.config_path,
    exclude = {},
    help = false,
    ignore_decorators = {},
    ignore_names = {},
    make_whitelist = false,
    min_confidence = TOOLING.min_confidence,
    paths = {
        'current-buffer-filename',
    },
    sort_by_size = false,
    verbose = false,
    version = false,
}

---@class VultureFinding
---@field confidence integer
---@field kind? string
---@field line integer
---@field message string
---@field path string
---@field size_lines? integer

---@class VultureDefinition:Linter
---@field cli_choices table<string, any>

---@type VultureDefinition
local M = {
    cli_choices = vim.deepcopy(CLI_CHOICES),
    cmd = TOOLING.executable,
}

local function validate_configuration()
    assert(TOOLING.config_path == '/dev/null')
    assert(TOOLING.executable == 'vulture')
    assert(TOOLING.min_confidence >= 0)
    assert(TOOLING.min_confidence <= 100)
    assert(TOOLING.timeout_ms >= 1000)
    assert(TOOLING.timeout_ms <= 300000)
    assert(LIMITS.diagnostics <= LIMITS.lines)
end

validate_configuration()

---@param filename string
---@return string
local function root_for_path(filename)
    if filename == '' then
        return uv.cwd() or '.'
    end

    return fs.root(filename, ROOT_MARKERS) or fs.dirname(filename) or uv.cwd() or '.'
end

---@param context LintContext
---@return string
local function root(context)
    return root_for_path(context.filename)
end

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
    assert(path ~= '')
    assert(cwd ~= '')

    if path:sub(1, 1) ~= '/' then
        path = fs.joinpath(cwd, path)
    end

    local normalized = fs.normalize(path)

    if normalized ~= nil then
        path = normalized
    end

    return uv.fs_realpath(path) or path
end

---@param context LintContext
---@return string[]
local function arguments(context)
    if context.filename == '' then
        error('Vulture requires a named file.', 0)
    end

    return {
        '--config=' .. TOOLING.config_path,
        '--min-confidence=' .. tostring(TOOLING.min_confidence),
        '--',
        context.filename,
    }
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

---@param value string|number|nil
---@param minimum integer
---@param maximum integer
---@return integer?
local function integer(value, minimum, maximum)
    local number = tonumber(value)

    if number == nil or number ~= math.floor(number) then
        return nil
    end

    if number < minimum or number > maximum then
        return nil
    end

    ---@cast number integer
    return number
end

---@param confidence integer
---@return integer
local function severity(confidence)
    assert(confidence >= 0)
    assert(confidence <= 100)

    if confidence == 100 then
        return diagnostic.severity.WARN
    end

    if confidence >= 90 then
        return diagnostic.severity.INFO
    end

    return diagnostic.severity.HINT
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
        source = 'vulture',
        code = code,
        message = clean(message),
    }
end

---@param context LintContext
---@param path string
---@return boolean
local function is_target(context, path)
    if path == '' or path:find('%z') ~= nil or context.filename == '' then
        return false
    end

    local cwd = root(context)
    local target = canonical(context.filename, cwd)

    return canonical(path, cwd) == target
end

---@param message string
---@return string? kind
local function finding_kind(message)
    local kind = message:match("^unused ([%a_]+) '[^']+'$")

    if kind ~= nil and CODES[kind] ~= nil then
        return kind
    end

    if message:match('^unreachable code') ~= nil then
        return 'unreachable_code'
    end

    return nil
end

---@param line string
---@return VultureFinding?
local function parse_finding(line)
    local path, line_number, message, confidence, size =
        line:match('^(.+):(%d+):%s+(.+)%s+%((%d+)%%%s+confidence,%s+(%d+)%s+lines?%)$')

    if path == nil then
        path, line_number, message, confidence = line:match('^(.+):(%d+):%s+(.+)%s+%((%d+)%%%s+confidence%)$')
    end

    local parsed_line = integer(line_number, 1, 2147483646)
    local parsed_confidence = integer(confidence, 0, 100)
    local parsed_size = integer(size, 1, 2147483646)

    if path == nil or message == nil or parsed_line == nil or parsed_confidence == nil then
        return nil
    end

    return {
        confidence = parsed_confidence,
        kind = finding_kind(message),
        line = parsed_line,
        message = message,
        path = path,
        size_lines = parsed_size,
    }
end

---@param bufnr integer
---@param row integer
---@param message string
---@return integer column
---@return integer end_column
local function columns(bufnr, row, message)
    local text = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

    if text == '' then
        return 0, 0
    end

    local name = message:match("'([^']+)'$")
    local first
    local final

    if name ~= nil and name ~= '' then
        first, final = text:find(name, 1, true)
    end

    if first == nil or final == nil then
        first = text:find('%S') or 1
        final = first
    end

    local column = first - 1
    local end_column = final

    if end_column < column then
        end_column = column
    end

    return column, end_column
end

---@param context LintContext
---@param finding VultureFinding
---@return vim.Diagnostic? item
---@return boolean malformed
---@return boolean foreign
local function diagnostic_for_finding(context, finding)
    if not is_target(context, finding.path) then
        return nil, false, true
    end

    local row = finding.line - 1
    local line_count = api.nvim_buf_line_count(context.bufnr)
    local malformed = false

    if line_count < 1 then
        line_count = 1
    end

    if row >= line_count then
        row = line_count - 1
        malformed = true
    end

    local column, end_column = columns(context.bufnr, row, finding.message)
    local code = CODES[finding.kind or ''] or ('confidence:%d'):format(finding.confidence)
    local item = status(context, code, finding.message)

    item.lnum = row
    item.end_lnum = row
    item.col = column
    item.end_col = end_column
    item.severity = severity(finding.confidence)
    item.user_data = {
        confidence = finding.confidence,
        kind = finding.kind,
        size_lines = finding.size_lines,
    }

    return item, malformed, false
end

---@param context LintContext
---@param line string
---@return vim.Diagnostic? item
---@return boolean malformed
---@return boolean foreign
local function parse_input_error(context, line)
    local path, line_number, message = line:match('^(.+):(%d+):%s+(.+)$')
    local parsed_line = integer(line_number, 1, 2147483646)

    if path == nil or message == nil or parsed_line == nil then
        return nil, true, false
    end

    if not is_target(context, path) then
        return nil, false, true
    end

    local row = parsed_line - 1
    local line_count = api.nvim_buf_line_count(context.bufnr)
    local malformed = false

    if line_count < 1 then
        line_count = 1
    end

    if row >= line_count then
        row = line_count - 1
        malformed = true
    end

    local column, end_column = columns(context.bufnr, row, message)
    local item = status(context, 'invalid-input', message)

    item.lnum = row
    item.end_lnum = row
    item.col = column
    item.end_col = end_column

    return item, malformed, false
end

---@param diagnostics vim.Diagnostic[]
---@param item vim.Diagnostic?
local function append(diagnostics, item)
    if item ~= nil and #diagnostics < LIMITS.diagnostics then
        diagnostics[#diagnostics + 1] = item
    end
end

---@param diagnostics vim.Diagnostic[]
---@param context LintContext
---@param malformed boolean
---@param foreign boolean
---@param limited boolean
---@param unmatched string?
local function append_statuses(diagnostics, context, malformed, foreign, limited, unmatched)
    if foreign then
        append(diagnostics, status(context, 'other-file', 'Vulture returned another file.'))
    end

    if malformed then
        append(diagnostics, status(context, 'malformed-result', 'Some Vulture results were malformed.'))
    end

    if limited then
        append(diagnostics, status(context, 'result-limit', 'The Vulture result limit was reached.'))
    end

    if unmatched ~= nil then
        append(diagnostics, status(context, 'vulture-error', unmatched))
    end
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
    if output == '' then
        return {}
    end

    if #output > LIMITS.output_bytes then
        return {
            status(context, 'output-limit', 'Vulture output exceeded 16 MiB.'),
        }
    end

    local diagnostics = {}
    local malformed = false
    local foreign = false
    local limited = false
    local unmatched
    local line_count = 0

    for line in output:gmatch('[^\r\n]+') do
        line_count = line_count + 1

        if line_count > LIMITS.lines or #diagnostics >= LIMITS.diagnostics - 4 then
            limited = true
            break
        end

        if #line > LIMITS.line_bytes then
            malformed = true
        else
            local finding = parse_finding(line)
            local item
            local bad
            local other

            if finding ~= nil then
                item, bad, other = diagnostic_for_finding(context, finding)
            else
                item, bad, other = parse_input_error(context, line)

                if item == nil and bad and not other and unmatched == nil then
                    unmatched = clean(line)
                    bad = false
                end
            end

            append(diagnostics, item)
            malformed = malformed or bad
            foreign = foreign or other
        end
    end

    append_statuses(diagnostics, context, malformed, foreign, limited, unmatched)

    return diagnostics
end

M.args = arguments
M.append_fname = false
M.automatic = false
M.cwd = root
M.env = {
    NO_COLOR = '1',
    PYTHONDONTWRITEBYTECODE = '1',
    PYTHONIOENCODING = 'utf-8',
    PYTHONUTF8 = '1',
}
M.exit_codes = {
    0,
    1,
    3,
}
M.ignore_exitcode = false
M.parser = parse
M.root_markers = ROOT_MARKERS
M.stdin = false
M.stream = 'both'
M.timeout = TOOLING.timeout_ms

return M
