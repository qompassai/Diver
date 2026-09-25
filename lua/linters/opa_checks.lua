-- #################################################################
-- /qompassai/lua/linters/opa_checks.lua
-- Native cds-snc/opa_checks Terraform-plan linter — Neovim 0.13+ / LuaJIT
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
---@source https://github.com/cds-snc/opa_checks/tree/9063d900522d427869a0f744b32946b49d719076
---@source https://github.com/open-policy-agent/conftest/blob/master/docs/output.md
local api = vim.api
local diagnostic = vim.diagnostic
local fs = vim.fs
local fn = vim.fn
local uv = vim.uv

local TOOLING = {
    executable = 'conftest',
    namespace = 'main',
    rego_version = 'v0',
    timeout_ms = 60000,
}
local ROOT_MARKERS = {
    '.opa_checks',
    '.terraform',
    'terraform.tfstate',
    '.git',
}
local LIMITS = {
    diagnostics = 512,
    issues = 511,
    message_bytes = 4096,
    output_bytes = 16 * 1024 * 1024,
    policy_entries = 4096,
    records = 1024,
}
---@class OpaChecksResultGroup
---@field code string
---@field field string
---@field severity integer

---@class OpaChecksRecord
---@field filename? string
---@field namespace? string
---@field exceptions? any[]
---@field failures? any[]
---@field warnings? any[]

---@class OpaChecksIssue
---@field msg string
---@field loc? { file?: string, line?: integer }
---@field metadata? { query?: string }

---@type OpaChecksResultGroup[]
local RESULT_GROUPS = {
    {
        code = 'exception',
        field = 'exceptions',
        severity = diagnostic.severity.ERROR,
    },
    {
        code = 'deny',
        field = 'failures',
        severity = diagnostic.severity.ERROR,
    },
    {
        code = 'warn',
        field = 'warnings',
        severity = diagnostic.severity.WARN,
    },
}

---@param context LintContext
---@return string
local function root(context)
    return fs.root(context.filename, ROOT_MARKERS) or context.root or context.cwd
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

    path = fs.normalize(path)

    return uv.fs_realpath(path) or path
end

---@param path string
---@return boolean
local function is_policy_directory(path)
    local stat = uv.fs_stat(path)

    if stat == nil or stat.type ~= 'directory' then
        return false
    end

    local scanner = uv.fs_scandir(path)

    if scanner == nil then
        return false
    end

    for _ = 1, LIMITS.policy_entries do
        local name, entry_type = uv.fs_scandir_next(scanner)

        if name == nil then
            return false
        end

        if entry_type ~= 'directory' and name:sub(-5) == '.rego' then
            return true
        end
    end

    return false
end

---@param candidates string[]
---@param path string
local function add_candidate(candidates, path)
    assert(#candidates < 16)

    if path == '' or path:find('%z') ~= nil then
        return
    end

    local normalized = fs.normalize(path)

    for _, candidate in ipairs(candidates) do
        if candidate == normalized then
            return
        end
    end

    candidates[#candidates + 1] = normalized
end

---@param context LintContext
---@return string[]
local function policy_candidates(context)
    local candidates = {}
    local configured = vim.env.OPA_CHECKS_POLICY_DIR

    if type(configured) == 'string' and configured ~= '' then
        add_candidate(candidates, configured)
        add_candidate(candidates, fs.joinpath(configured, 'aws_terraform'))

        return candidates
    end

    local project_root = root(context)

    add_candidate(candidates, fs.joinpath(project_root, 'aws_terraform'))
    add_candidate(candidates, fs.joinpath(project_root, '.opa_checks', 'aws_terraform'))
    add_candidate(candidates, fs.joinpath(project_root, 'opa_checks', 'aws_terraform'))
    add_candidate(candidates, fs.joinpath(project_root, 'vendor', 'opa_checks', 'aws_terraform'))
    add_candidate(candidates, fs.joinpath(fn.stdpath('data'), 'opa_checks', 'aws_terraform'))
    add_candidate(candidates, '/usr/share/opa_checks/aws_terraform')

    return candidates
end

---@param context LintContext
---@return string
local function policy_directory(context)
    local candidates = policy_candidates(context)

    for _, candidate in ipairs(candidates) do
        if is_policy_directory(candidate) then
            return canonical(candidate, root(context))
        end
    end

    local configured = vim.env.OPA_CHECKS_POLICY_DIR

    if type(configured) == 'string' and configured ~= '' then
        error('OPA_CHECKS_POLICY_DIR does not contain readable Rego policies', 0)
    end

    error('opa_checks policies not found; set OPA_CHECKS_POLICY_DIR to the clone or policy directory', 0)
end

---@param context LintContext
---@return string[]
local function arguments(context)
    assert(context.filename ~= '')
    assert(not context.modified)
    assert(context.filename:lower():sub(-5) == '.json')

    local filename = canonical(context.filename, context.cwd)
    local stat = uv.fs_stat(filename)

    assert(stat ~= nil)
    assert(stat.type == 'file')

    return {
        'test',
        '--output=json',
        '--namespace=' .. TOOLING.namespace,
        '--parser=json',
        '--rego-version=' .. TOOLING.rego_version,
        '--fail-on-warn',
        '--no-color',
        '--policy=' .. policy_directory(context),
        '--',
        filename,
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
---@return boolean
local function positive_integer(value)
    return type(value) == 'number' and value >= 1 and value < 2147483647 and value == math.floor(value)
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
        severity = severity or diagnostic.severity.WARN,
        source = 'opa_checks',
        code = code,
        message = clean(message),
    }
end

---@param context LintContext
---@param line any
---@return integer, integer
local function position(context, line)
    if not positive_integer(line) then
        return 0, 0
    end

    local line_count = math.max(api.nvim_buf_line_count(context.bufnr), 1)
    local row = math.min(line - 1, line_count - 1)
    local text = api.nvim_buf_get_lines(context.bufnr, row, row + 1, false)[1] or ''

    return row, #text
end

---@param context LintContext
---@param path any
---@return boolean
local function is_target(context, path)
    if type(path) ~= 'string' or path == '' or path:find('%z') ~= nil then
        return false
    end

    local target = canonical(context.filename, context.cwd)

    return canonical(path, root(context)) == target
end

---@param context LintContext
---@param record OpaChecksRecord
---@param group OpaChecksResultGroup
---@param issue any
---@return vim.Diagnostic?
---@return boolean malformed
local function parse_issue(context, record, group, issue)
    if type(issue) ~= 'table' or type(issue.msg) ~= 'string' or issue.msg == '' then
        return nil, true
    end

    ---@cast issue OpaChecksIssue
    local namespace = TOOLING.namespace

    if type(record.namespace) == 'string' and record.namespace ~= '' then
        namespace = record.namespace
    end

    local malformed = false
    local query

    if issue.metadata ~= nil then
        if type(issue.metadata) ~= 'table' then
            malformed = true
        elseif issue.metadata.query ~= nil and type(issue.metadata.query) ~= 'string' then
            malformed = true
        elseif type(issue.metadata.query) == 'string' then
            query = clean(issue.metadata.query)
        end
    end

    local item = status(context, query or (namespace .. '/' .. group.code), issue.msg, group.severity)
    local reported_file
    local reported_line

    if issue.loc ~= nil then
        if type(issue.loc) ~= 'table' then
            malformed = true
        else
            reported_file = issue.loc.file
            reported_line = issue.loc.line

            if reported_file ~= nil and type(reported_file) ~= 'string' then
                malformed = true
            end

            if reported_line ~= nil and not positive_integer(reported_line) then
                malformed = true
            end
        end
    end

    if is_target(context, reported_file) then
        local row, end_column = position(context, reported_line)

        item.lnum = row
        item.end_lnum = row
        item.end_col = end_column
    end

    item.user_data = {
        namespace = namespace,
        query = query,
        reported_file = type(reported_file) == 'string' and clean(reported_file) or nil,
        reported_line = positive_integer(reported_line) and reported_line or nil,
    }

    return item, malformed
end

---@param diagnostics vim.Diagnostic[]
---@param context LintContext
---@param record OpaChecksRecord
---@param group OpaChecksResultGroup
---@return boolean malformed
---@return boolean limited
local function append_group(diagnostics, context, record, group)
    local issues = record[group.field]

    if issues == nil then
        return false, false
    end

    if type(issues) ~= 'table' or not vim.islist(issues) then
        return true, false
    end

    local malformed = false

    for index = 1, #issues do
        if #diagnostics >= LIMITS.issues then
            return malformed, true
        end

        local item, item_malformed = parse_issue(context, record, group, issues[index])

        malformed = malformed or item_malformed

        if item ~= nil then
            diagnostics[#diagnostics + 1] = item
        end
    end

    return malformed, false
end

---@param diagnostics vim.Diagnostic[]
---@param context LintContext
---@param record any
---@return boolean malformed
---@return boolean limited
---@return boolean foreign
local function append_record(diagnostics, context, record)
    if type(record) ~= 'table' then
        return true, false, false
    end

    ---@cast record OpaChecksRecord
    if record.filename ~= nil and type(record.filename) ~= 'string' then
        return true, false, false
    end

    if type(record.filename) == 'string' and not is_target(context, record.filename) then
        return false, false, true
    end

    local malformed = record.namespace ~= nil and type(record.namespace) ~= 'string'

    for _, group in ipairs(RESULT_GROUPS) do
        local group_malformed, group_limited = append_group(diagnostics, context, record, group)

        malformed = malformed or group_malformed

        if group_limited then
            return malformed, true, false
        end
    end

    return malformed, false, false
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
---@return any[]? report
---@return vim.Diagnostic? problem
local function decode_report(output, context)
    if #output > LIMITS.output_bytes then
        return nil, status(context, 'output-limit', 'opa_checks output exceeded 16 MiB.')
    end

    local text = vim.trim(output)
    local decoded, report = pcall(vim.json.decode, text)

    if not decoded or type(report) ~= 'table' or not vim.islist(report) or text:sub(1, 1) ~= '[' then
        return nil,
            status(
                context,
                'invalid-report',
                'Conftest returned no valid JSON report; inspect stderr and the Rego v0 policies.'
            )
    end

    return report, nil
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic[]
local function parse(output, context)
    if context.modified then
        return {
            status(context, 'save-required', 'Save this buffer before running opa_checks.'),
        }
    end

    local report, problem = decode_report(output, context)

    if report == nil then
        assert(problem ~= nil)
        return {
            problem,
        }
    end

    local diagnostics = {}
    local foreign = false
    local malformed = false
    local limited = #report > LIMITS.records

    for index = 1, math.min(#report, LIMITS.records) do
        local record_malformed, record_limited, record_foreign = append_record(diagnostics, context, report[index])

        malformed = malformed or record_malformed
        limited = limited or record_limited
        foreign = foreign or record_foreign

        if record_limited then
            break
        end
    end

    if foreign then
        append_status(
            diagnostics,
            status(context, 'other-files', 'Conftest returned results for a different input file.')
        )
    end

    if malformed then
        append_status(
            diagnostics,
            status(context, 'malformed-result', 'Some Conftest results were malformed and omitted.')
        )
    end

    if limited then
        append_status(
            diagnostics,
            status(context, 'result-limit', 'The editor result limit was reached; run Conftest for all findings.')
        )
    end

    return diagnostics
end

---@type Linter
return {
    cmd = TOOLING.executable,
    args = arguments,
    append_fname = false,
    automatic = false,
    cwd = root,
    env = {
        NO_COLOR = '1',
    },
    exit_codes = {
        0,
        1,
        2,
    },
    ignore_exitcode = false,
    parser = parse,
    root_markers = ROOT_MARKERS,
    stdin = false,
    stream = 'stdout',
    timeout = TOOLING.timeout_ms,
}
