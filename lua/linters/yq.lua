-- #################################################################
-- /qompassai/Diver/lua/linters/yq.lua
-- Native yq YAML syntax linter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/mikefarah/yq/tree/c14f446382944492701b16c1ddb48bb9dbe683e3
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local TOOLING = {
    executable = 'yq',
    input_format = 'yaml',
    output_format = 'json',
    timeout_ms = 15000,
}
local ROOT_MARKERS = {
    'Chart.yaml',
    'kustomization.yaml',
    'compose.yaml',
    'compose.yml',
    'docker-compose.yaml',
    'docker-compose.yml',
    'ansible.cfg',
    'pyproject.toml',
    'package.json',
    'Cargo.toml',
    '.git',
}
local LIMITS = {
    message_bytes = 4096,
    output_bytes = 1024 * 1024,
}

local ARGUMENTS = {
    'eval',
    '--input-format=' .. TOOLING.input_format,
    '--output-format=' .. TOOLING.output_format,
    '--no-colors',
    '--no-doc',
    '--exit-status',
    '--header-preprocess=true',
    '--string-interpolation=false',
    '--yaml-fix-merge-anchor-to-spec',
    '--security-disable-env-ops',
    '--security-disable-file-ops',
    'true',
    '-',
}

-- Explicit audit inventory for yq 4.53.6 lint-mode choices. False choices
-- are intentional exclusions, not unspecified defaults.
local CLI_CHOICES = {
    command = 'eval',
    debug_node_info = false,
    expression = 'true',
    expression_file = false,
    exit_status = true,
    force_color = false,
    front_matter = 'none',
    header_preprocess = true,
    help = false,
    inplace = false,
    input_filename = '-',
    input_format = TOOLING.input_format,
    null_input = false,
    output_format = TOOLING.output_format,
    output_document_separator = false,
    output_unwrap_scalar = true,
    pretty_print = false,
    security = {
        environment_operators = false,
        file_operators = false,
        system_operator = false,
    },
    split_expression = false,
    stdin = true,
    string_interpolation = false,
    verbose = false,
    version = false,
    yaml_compact_sequence_indent = false,
    yaml_fix_merge_anchor_to_spec = true,
}

---@class YqDefinition:Linter
---@field cli_choices table<string, any>

---@type YqDefinition
local M = {
    cli_choices = vim.deepcopy(CLI_CHOICES),
    cmd = TOOLING.executable,
}

local function validate_configuration()
    assert(TOOLING.executable == 'yq')
    assert(TOOLING.input_format == 'yaml')
    assert(TOOLING.output_format == 'json')
    assert(TOOLING.timeout_ms >= 1000)
    assert(TOOLING.timeout_ms <= 300000)
    assert(ARGUMENTS[#ARGUMENTS - 1] == 'true')
    assert(ARGUMENTS[#ARGUMENTS] == '-')

    local joined = table.concat(ARGUMENTS, '\0')

    assert(joined:find('%-%-inplace', 1, false) == nil)
    assert(joined:find('%-%-from%-file', 1, false) == nil)
    assert(joined:find('%-%-split%-exp', 1, false) == nil)
    assert(joined:find('%-%-security%-enable%-system%-operator', 1, false) == nil)
    assert(joined:find('%-%-security%-disable%-env%-ops', 1, false) ~= nil)
    assert(joined:find('%-%-security%-disable%-file%-ops', 1, false) ~= nil)
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
---@return integer?
local function positive_integer(value)
    local number = tonumber(value)

    if number == nil or number ~= math.floor(number) then
        return nil
    end

    if number < 1 or number >= 2147483647 then
        return nil
    end

    ---@cast number integer
    return number
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
        source = 'yq',
        code = code,
        message = clean(message),
    }
end

---@param bufnr integer
---@param reported_line integer
---@param reported_column integer
---@return integer row
---@return integer column
---@return boolean malformed
local function position(bufnr, reported_line, reported_column)
    local row = reported_line - 1
    local column = reported_column - 1
    local line_count = api.nvim_buf_line_count(bufnr)
    local malformed = false

    if line_count < 1 then
        line_count = 1
    end

    if row >= line_count then
        row = line_count - 1
        malformed = true
    end

    local text = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ''

    if column > #text then
        column = #text
        malformed = true
    end

    while column > 0 do
        local byte = text:byte(column + 1)

        if byte == nil or byte < 128 or byte >= 192 then
            break
        end

        column = column - 1
        malformed = true
    end

    return row, column, malformed
end

---@param text string
---@return integer? start_line
---@return integer? start_column
---@return integer? end_line
---@return integer? end_column
local function parse_range(text)
    local first_line, first_column, last_line, last_column = text:match('at L(%d+)%.C(%d+)%-L(%d+)%.C(%d+):')

    if first_line ~= nil then
        return positive_integer(first_line),
            positive_integer(first_column),
            positive_integer(last_line),
            positive_integer(last_column)
    end

    local line, column = text:match('at L(%d+)%.C(%d+):')

    if line ~= nil then
        local parsed_line = positive_integer(line)
        local parsed_column = positive_integer(column)

        return parsed_line, parsed_column, parsed_line, parsed_column
    end

    line = text:match('[Yy][Aa][Mm][Ll]: line (%d+):')

    if line ~= nil then
        local parsed_line = positive_integer(line)

        return parsed_line, 1, parsed_line, 1
    end

    return nil, nil, nil, nil
end

---@param text string
---@return string
local function error_message(text)
    local message = vim.trim(text)

    message = message:gsub('^Error:%s*', '')
    message = message:gsub("^bad file '%-':%s*", '')

    if message == '' then
        return 'yq exited with an empty error report.'
    end

    return clean(message)
end

---@param context LintContext
---@param text string
---@return vim.Diagnostic
local function diagnostic_for(context, text)
    local start_line, start_column, end_line, end_column = parse_range(text)
    local item = status(context, 'yq-error', error_message(text))

    if start_line == nil or start_column == nil or end_line == nil or end_column == nil then
        return item
    end

    local row, column, start_malformed = position(context.bufnr, start_line, start_column)
    local end_row, final_column, end_malformed = position(context.bufnr, end_line, end_column)

    item.code = 'yaml-syntax'

    if start_malformed or end_malformed then
        item.code = 'malformed-range'
    end
    item.lnum = row
    item.col = column

    if end_row < row then
        item.end_lnum = row
        item.end_col = column
        item.code = 'malformed-range'
    else
        item.end_lnum = end_row
        item.end_col = final_column

        if end_row == row and item.end_col <= column then
            local line = api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1]
            local next_column = column + 1

            if next_column > #(line or '') then
                next_column = #(line or '')
            end

            item.end_col = next_column
        end
    end

    return item
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
            status(context, 'output-limit', 'yq stderr exceeded 1 MiB.'),
        }
    end

    return {
        diagnostic_for(context, output),
    }
end

M.args = vim.deepcopy(ARGUMENTS)
M.append_fname = false
M.automatic = true
M.cwd = root
M.env = {
    NO_COLOR = '1',
}
M.exit_codes = {
    0,
    1,
}
M.ignore_exitcode = false
M.parser = parse
M.root_markers = ROOT_MARKERS
M.stdin = true
M.stream = 'stderr'
M.timeout = TOOLING.timeout_ms

return M
