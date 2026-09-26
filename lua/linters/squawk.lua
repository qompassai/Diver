-- #################################################################
-- /qompassai/Diver/lua/linters/squawk.lua
-- Native Squawk PostgreSQL migration linter — Neovim 0.13+ / LuaJIT
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
---@source https://github.com/sbdchd/squawk/tree/2167b892a6f204c96b08b522df782a88898c1d2d
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local uv = vim.uv

local TOOLING = {
    config_path = '/dev/null',
    executable = 'squawk',
    pg_version = '15.0.0',
    timeout_ms = 30000,
}
local ROOT_MARKERS = {
    '.squawk.toml',
    'atlas.hcl',
    'dbmate.env',
    'flyway.conf',
    'liquibase.properties',
    'sqlc.yaml',
    'sqlc.yml',
    'Cargo.toml',
    'package.json',
    '.git',
}
local LIMITS = {
    diagnostics = 512,
    issues = 511,
    message_bytes = 4096,
    output_bytes = 16 * 1024 * 1024,
}
local SEVERITIES = {
    Error = diagnostic.severity.ERROR,
    Warning = diagnostic.severity.WARN,
}

local ACTIVE_RULES = {
    'require-concurrent-index-creation',
    'require-concurrent-index-deletion',
    'constraint-missing-not-valid',
    'adding-field-with-default',
    'adding-foreign-key-constraint',
    'changing-column-type',
    'adding-not-nullable-field',
    'adding-serial-primary-key-field',
    'renaming-column',
    'renaming-table',
    'disallowed-unique-constraint',
    'ban-drop-database',
    'prefer-bigint-over-int',
    'prefer-bigint-over-smallint',
    'prefer-identity',
    'prefer-repack',
    'prefer-robust-stmts',
    'prefer-text-field',
    'prefer-timestamp-tz',
    'ban-char-field',
    'ban-drop-column',
    'ban-drop-table',
    'ban-drop-not-null',
    'transaction-nesting',
    'adding-required-field',
    'ban-concurrent-index-creation-in-transaction',
    'unused-ignore',
    'ban-create-domain-with-constraint',
    'ban-alter-domain-with-add-constraint',
    'ban-truncate-cascade',
    'ban-uncommitted-transaction',
    'require-enum-value-ordering',
    'require-table-schema',
    'identifier-too-long',
    'require-concurrent-partition-detach',
    'require-concurrent-reindex',
    'require-lock-timeout',
    'require-statement-timeout',
    'ban-duplicate-column-assignments',
}
local INCLUDED_RULES = {
    'require-table-schema',
}
local EXCLUDED_RULES = {}
local RULE_ALIASES = {
    ['prefer-timestamptz'] = 'prefer-timestamp-tz',
    ['require-timeout-settings'] = 'require-lock-timeout,require-statement-timeout',
}

-- Complete lint-mode choice inventory for Squawk 2.65.0. False and empty
-- values are deliberate; unsupported subcommands never run from the linter.
local CLI_CHOICES = {
    assume_in_transaction = false,
    command = 'lint',
    commands = {
        lint = true,
        server = false,
        upload_to_github = false,
    },
    config_path = TOOLING.config_path,
    debug = false,
    debug_formats = {
        ast = false,
        lex = false,
        parse = false,
    },
    excluded_paths = {},
    excluded_rules = EXCLUDED_RULES,
    github_annotations = false,
    help = false,
    included_rules = INCLUDED_RULES,
    no_error_on_unmatched_pattern = false,
    path_patterns = {},
    pg_version = TOOLING.pg_version,
    reporter = 'json',
    reporters = {
        gcc = false,
        gitlab = false,
        json = true,
        tty = false,
    },
    server = false,
    stdin = true,
    stdin_filepath = 'current-buffer-filename',
    upload_to_github = false,
    upload_to_github_options = {
        fail_on_violations = false,
        github_api_url = false,
        github_app_id = false,
        github_install_id = false,
        github_private_key = false,
        github_private_key_base64 = false,
        github_pr_number = false,
        github_repo_name = false,
        github_repo_owner = false,
        github_token = false,
        paths = {},
    },
    verbose = false,
    version = false,
}

---@class SquawkReport
---@field file string
---@field line integer
---@field column integer
---@field level 'Error'|'Warning'
---@field message string
---@field help? string
---@field rule_name string
---@field column_end integer
---@field line_end integer

---@class SquawkDefinition:Linter
---@field active_rules string[]
---@field cli_choices table<string, any>
---@field rule_aliases table<string, string>

---@type SquawkDefinition
local M = {
    active_rules = vim.deepcopy(ACTIVE_RULES),
    cli_choices = vim.deepcopy(CLI_CHOICES),
    cmd = TOOLING.executable,
    rule_aliases = vim.deepcopy(RULE_ALIASES),
}

local function validate_configuration()
    assert(#ACTIVE_RULES == 39)
    assert(#INCLUDED_RULES == 1)
    assert(#EXCLUDED_RULES == 0)
    assert(TOOLING.config_path == '/dev/null')
    assert(TOOLING.pg_version:match('^%d+%.%d+%.%d+$') ~= nil)
    assert(TOOLING.timeout_ms >= 1000)
    assert(TOOLING.timeout_ms <= 300000)

    local seen = {}

    for _, name in ipairs(ACTIVE_RULES) do
        assert(type(name) == 'string')
        assert(name ~= '')
        assert(seen[name] == nil)
        seen[name] = true
    end

    for _, name in ipairs(INCLUDED_RULES) do
        assert(seen[name] == true)
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
    return root_for_path(context.filename)
end

---@param path string
---@param cwd string
---@return string
local function canonical(path, cwd)
    assert(type(path) == 'string')
    assert(type(cwd) == 'string')

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
    assert(context.filename ~= '')

    local project_root = root(context)
    local filename = canonical(context.filename, project_root)

    return {
        '--reporter=json',
        '--config=' .. TOOLING.config_path,
        '--pg-version=' .. TOOLING.pg_version,
        '--include=' .. table.concat(INCLUDED_RULES, ','),
        '--no-assume-in-transaction',
        '--stdin-filepath=' .. filename,
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

---@param value any
---@return integer?
local function integer(value)
    if type(value) ~= 'number' or value ~= math.floor(value) then
        return nil
    end

    if value < 0 or value >= 2147483647 then
        return nil
    end

    ---@cast value integer
    return value
end

---@param context LintContext
---@param code string
---@param message string
---@param severity? integer
---@return vim.Diagnostic
local function status(context, code, message, severity)
    return {
        bufnr = context.bufnr,
        lnum = 0,
        end_lnum = 0,
        col = 0,
        end_col = 0,
        severity = severity or diagnostic.severity.ERROR,
        source = 'squawk',
        code = code,
        message = clean(message),
    }
end

---@param bufnr integer
---@param reported_line any
---@param reported_column any
---@return integer row
---@return integer column
---@return boolean malformed
local function position(bufnr, reported_line, reported_column)
    local row = integer(reported_line)
    local column = integer(reported_column)
    local line_count = math.max(api.nvim_buf_line_count(bufnr), 1)

    if row == nil or column == nil then
        return 0, 0, true
    end

    local malformed = row >= line_count

    row = math.min(row, line_count - 1)

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

---@param context LintContext
---@param path any
---@return boolean
local function is_target(context, path)
    if type(path) ~= 'string' or path == '' or path:find('%z') ~= nil then
        return false
    end

    local project_root = root(context)
    local target = canonical(context.filename, project_root)

    return canonical(path, project_root) == target
end

---@param record SquawkReport
---@return string message
---@return string? help
---@return boolean malformed
local function message_for(record)
    local help = record.help
    local malformed = help ~= nil and type(help) ~= 'string'

    if type(help) ~= 'string' or help == '' then
        return clean(record.message), nil, malformed
    end

    return clean(record.message .. ' Help: ' .. help), clean(help), malformed
end

---@param context LintContext
---@param record any
---@return vim.Diagnostic? item
---@return boolean malformed
---@return boolean foreign
local function parse_record(context, record)
    if
        type(record) ~= 'table'
        or type(record.file) ~= 'string'
        or type(record.level) ~= 'string'
        or type(record.message) ~= 'string'
        or record.message == ''
        or type(record.rule_name) ~= 'string'
        or record.rule_name == ''
    then
        return nil, true, false
    end

    ---@cast record SquawkReport
    if not is_target(context, record.file) then
        return nil, false, true
    end

    local severity = SEVERITIES[record.level]
    local row, column, start_malformed = position(context.bufnr, record.line, record.column)
    local end_row, end_column, end_malformed = position(context.bufnr, record.line_end, record.column_end)
    local message, help, help_malformed = message_for(record)
    local malformed = severity == nil or start_malformed or end_malformed or help_malformed
    local item = status(context, clean(record.rule_name), message, severity)

    item.lnum = row
    item.col = column

    if end_row < row then
        item.end_lnum = row
        item.end_col = column
        malformed = true
    else
        item.end_lnum = end_row
        item.end_col = end_row == row and math.max(end_column, column) or end_column
    end

    item.user_data = {
        help = help,
        rule = clean(record.rule_name),
    }

    return item, malformed, false
end

---@param diagnostics vim.Diagnostic[]
---@param item vim.Diagnostic
local function append_status(diagnostics, item)
    if #diagnostics < LIMITS.diagnostics then
        diagnostics[#diagnostics + 1] = item
    end
end

---@param output string
---@param context LintContext
---@return any[]? records
---@return vim.Diagnostic? problem
local function decode_records(output, context)
    if #output > LIMITS.output_bytes then
        return nil, status(context, 'output-limit', 'Squawk output exceeded 16 MiB.')
    end

    local text = vim.trim(output)
    local decoded, records = pcall(vim.json.decode, text)

    if not decoded or type(records) ~= 'table' or not vim.islist(records) then
        return nil,
            status(
                context,
                'invalid-report',
                'Squawk returned no valid JSON report; run the CLI to inspect the failure.'
            )
    end

    return records, nil
end

---@param diagnostics vim.Diagnostic[]
---@param context LintContext
---@param malformed boolean
---@param foreign boolean
---@param limited boolean
local function append_parse_statuses(diagnostics, context, malformed, foreign, limited)
    if foreign then
        append_status(diagnostics, status(context, 'other-file', 'Squawk returned a result for another file.'))
    end

    if malformed then
        append_status(diagnostics, status(context, 'malformed-result', 'Some Squawk results were malformed.'))
    end

    if limited then
        append_status(
            diagnostics,
            status(context, 'result-limit', 'The result limit was reached; run Squawk for all findings.')
        )
    end
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
    local records, problem = decode_records(output, context)

    if records == nil then
        assert(problem ~= nil)

        return {
            problem,
        }
    end

    local diagnostics = {}
    local malformed = false
    local foreign = false
    local limited = #records > LIMITS.issues

    for index = 1, math.min(#records, LIMITS.issues) do
        local item, item_malformed, item_foreign = parse_record(context, records[index])

        malformed = malformed or item_malformed
        foreign = foreign or item_foreign

        if item ~= nil then
            diagnostics[#diagnostics + 1] = item
        end
    end

    append_parse_statuses(diagnostics, context, malformed, foreign, limited)

    return diagnostics
end

M.args = arguments
M.append_fname = false
M.automatic = true
M.cwd = root
M.env = {
    NO_COLOR = '1',
    RUST_BACKTRACE = '0',
    SQUAWK_DISABLE_GITHUB_ANNOTATIONS = '1',
}
M.exit_codes = {
    0,
    1,
}
M.ignore_exitcode = false
M.parser = parse
M.root_markers = ROOT_MARKERS
M.stdin = true
M.stream = 'stdout'
M.timeout = TOOLING.timeout_ms

return M
