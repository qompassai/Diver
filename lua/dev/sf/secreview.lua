-- /qompassai/Diver/lua/dev/sf/secreview.lua
-- Qompass AI Diver Salesforce AgentExchange Security Review Utils
---@module 'dev.sf.secreview'
-- Pre-submission tooling for the AgentExchange / AppExchange security review:
-- an interactive checklist, a security-preset Code Analyzer scan
-- (critical + high severities, the review's bar), and a pass/fail gate.
--
-- Repo convention: components are kept in alphabetical order wherever the
-- language allows it (dependency order wins for local functions).
local api = vim.api
local core = require('dev.sf.core')
local fn = vim.fn
local uv = vim.uv

local M = {}

-- Bounds: keep every scan, buffer, and report finite.
local CHECKLIST_HEIGHT = 24
local GATE_HEIGHT = 18
local SEVERITY_THRESHOLD = '2' -- critical + high only: the review's bar
local TERMINAL_HEIGHT = 20
local TOP_RULES_MAX = 10

---@class SfSecReviewItem
---@field id string stable identifier used for persisted state
---@field title string short imperative title
---@field detail string one-line explanation

---@class SfSecReviewSection
---@field title string section heading
---@field items SfSecReviewItem[]

---@type SfSecReviewSection[]
local SECTIONS = {
    {
        title = '1. Apex data access',
        items = {
            {
                id = 'apex-dml-fls',
                title = 'Enforce FLS on every DML path',
                detail = 'Security.stripInaccessible() applied to the records actually inserted or updated.',
            },
            {
                id = 'apex-sharing',
                title = 'Declare sharing on every DML class',
                detail = 'with sharing (or inherited sharing); without sharing needs a written justification.',
            },
            {
                id = 'apex-soql-injection',
                title = 'No dynamic SOQL concatenation',
                detail = 'Bind variables or Database.queryWithBinds(..., USER_MODE); escapeSingleQuotes '
                    .. 'only works inside quoted positions.',
            },
            {
                id = 'apex-user-mode',
                title = 'Enforce user mode on every query',
                detail = 'WITH USER_MODE on all SOQL/SOSL; WITH SECURITY_ENFORCED is rejected at API 67.0+.',
            },
        },
    },
    {
        title = '2. Input handling and output encoding',
        items = {
            {
                id = 'aura-public',
                title = 'Treat @AuraEnabled as public',
                detail = 'Every @AuraEnabled method assumed callable with arbitrary parameters.',
            },
            {
                id = 'csrf',
                title = 'No state change on GET',
                detail = 'No DML in constructors or @AuraEnabled(cacheable=true) getters.',
            },
            {
                id = 'open-redirect',
                title = 'No open redirects',
                detail = 'User-controlled redirect targets allowlisted to relative paths.',
            },
            {
                id = 'xss',
                title = 'No XSS sinks',
                detail = 'No innerHTML in LWC; no unescaped Visualforce output.',
            },
        },
    },
    {
        title = '3. Secrets, transport, crypto',
        items = {
            {
                id = 'crypto',
                title = 'No hardcoded crypto material',
                detail = 'No hardwired keys or IVs in Crypto calls.',
            },
            {
                id = 'debug-pii',
                title = 'No PII in logs',
                detail = 'System.debug scrubbed; no APEX_CODE=FINEST in production.',
            },
            {
                id = 'https',
                title = 'HTTPS everywhere',
                detail = 'No http:// endpoints.',
            },
            {
                id = 'secrets',
                title = 'No hardcoded secrets',
                detail = 'All auth via Named Credentials / External Credentials.',
            },
        },
    },
    {
        title = '4. Packaging hygiene',
        items = {
            {
                id = 'least-privilege',
                title = 'Least-privilege integration access',
                detail = 'Object-scoped permission sets; never Modify All Data for integrations.',
            },
            {
                id = 'no-hardcoded-ids',
                title = 'No hardcoded record IDs',
                detail = 'Query by DeveloperName or ExternalId.',
            },
            {
                id = 'package-2gp',
                title = '2GP managed package',
                detail = 'Namespace registered; beta version tested before release.',
            },
            {
                id = 'self-contained',
                title = 'Package is self-contained',
                detail = 'No references to actions, topics, or data outside the package.',
            },
        },
    },
    {
        title = '5. AgentExchange surface',
        items = {
            {
                id = 'composable',
                title = 'Action-oriented components',
                detail = 'Discrete Actions / Topics / Prompt Templates an agent invokes; not UI-buried features.',
            },
            {
                id = 'connected-app',
                title = 'Connected App hardening',
                detail = 'External Client App hardening complete (mandatory since 2026-05-11).',
            },
            {
                id = 'dast',
                title = 'DAST on external endpoints',
                detail = 'ZAP, Burp, or Qualys report covers every external endpoint.',
            },
            {
                id = 'data-flows',
                title = 'Data flows documented',
                detail = 'Every external endpoint, permission scope, and handling decision written down.',
            },
            {
                id = 'mcp-auth',
                title = 'MCP auth model documented',
                detail = 'No secrets in config; minimal token scope. (Only when shipping an MCP server.)',
            },
            {
                id = 'test-org',
                title = 'Test org ready',
                detail = 'Pre-loaded data, login steps, URLs and credentials for external components.',
            },
        },
    },
    {
        title = '6. Submission mechanics',
        items = {
            {
                id = 'false-positives',
                title = 'False positives documented',
                detail = 'Each with reasoning; reviewers accept documented FPs, not silent ones.',
            },
            {
                id = 'free-vs-paid',
                title = 'Free vs paid decided',
                detail = 'Free listing: fee waiver code, $0 fee, $0 rev share.',
            },
            {
                id = 'listing-assets',
                title = 'Listing assets ready',
                detail = 'Intent-search copy, input/output schemas, install guide, screenshots, <3-min demo video.',
            },
            {
                id = 'scans-ready',
                title = 'Scan artifacts ready',
                detail = 'Code Analyzer + Checkmarx reports in hand; 3 free Checkmarx scans per review, '
                    .. 'do not burn early.',
            },
        },
    },
}

---@type table<string, SfSecReviewItem>
local ITEM_BY_ID = {}
for _, section in ipairs(SECTIONS) do
    for _, item in ipairs(section.items) do
        assert(type(item.id) == 'string' and item.id ~= '', 'Security review item is missing an id')
        assert(ITEM_BY_ID[item.id] == nil, ('Duplicate security review item id: %s'):format(item.id))
        ITEM_BY_ID[item.id] = item
    end
end

local STATE_DIR = vim.fs.joinpath(fn.stdpath('data'), 'diver', 'sf')
local STATE_FILE = vim.fs.joinpath(STATE_DIR, 'secreview.json')

---@param value any
---@return string? bucket name for critical/high, nil otherwise
local function gate_bucket(value)
    local numeric = tonumber(value)
    if numeric == 1 then
        return 'critical'
    elseif numeric == 2 then
        return 'high'
    end
    local label = tostring(value or ''):lower()
    if label == 'critical' or label == 'sev1' then
        return 'critical'
    elseif label == 'high' or label == 'sev2' then
        return 'high'
    end
    return nil
end

---@return table<string, boolean> checked ids
local function load_state()
    -- A missing state file is normal on first run, not an error.
    local file = io.open(STATE_FILE, 'rb')
    if not file then
        return {}
    end
    local content = file:read('*a')
    file:close()
    if type(content) ~= 'string' or content == '' then
        return {}
    end
    local ok, decoded = pcall(vim.json.decode, content)
    if not ok or type(decoded) ~= 'table' then
        return {}
    end
    -- Prune ids that no longer exist so stale state can never resurrect.
    local state = {}
    for id, value in pairs(decoded) do
        if ITEM_BY_ID[id] ~= nil and value == true then
            state[id] = true
        end
    end
    return state
end

---@param state table<string, boolean>
---@return string[] lines
---@return table<integer, string> line_numbers to item ids
local function render_lines(state)
    local lines = {
        '# AgentExchange security review checklist',
        '# <CR> or <Space> toggles an item, q closes. State persists across sessions.',
        '',
    }
    ---@type table<integer, string>
    local index = {}
    for _, section in ipairs(SECTIONS) do
        lines[#lines + 1] = '## ' .. section.title
        lines[#lines + 1] = ''
        for _, item in ipairs(section.items) do
            local mark = state[item.id] and 'x' or ' '
            lines[#lines + 1] = ('- [%s] %s — %s'):format(mark, item.title, item.detail)
            index[#lines] = item.id
        end
        lines[#lines + 1] = ''
    end
    return lines, index
end

---@param opts? SfCommandArgs
---@return string target workspace path or file
local function resolve_target(opts)
    local arg = core.get_arg(opts)
    if type(arg) == 'string' and arg ~= '' then
        return arg
    end
    local bufname = api.nvim_buf_get_name(0)
    if bufname ~= '' then
        return bufname
    end
    return 'force-app'
end

---@param state table<string, boolean>
---@return boolean
local function save_state(state)
    fn.mkdir(STATE_DIR, 'p')
    local file, open_error = io.open(STATE_FILE, 'wb')
    if not file then
        core.notify(('Unable to write security review state: %s'):format(open_error or 'unknown'), vim.log.levels.ERROR)
        return false
    end
    file:write(vim.json.encode(state))
    file:close()
    return true
end

---@param decoded table
---@return integer critical_count
---@return integer high_count
---@return table<string, integer> rule_counts
local function summarize_gate(decoded)
    local critical_count, high_count = 0, 0
    ---@type table<string, integer>
    local rule_counts = {}
    local violations = type(decoded.violations) == 'table' and decoded.violations or {}
    for _, violation in ipairs(violations) do
        if type(violation) == 'table' then
            local bucket = gate_bucket(violation.severity)
            if bucket == 'critical' then
                critical_count = critical_count + 1
            elseif bucket == 'high' then
                high_count = high_count + 1
            end
            if bucket ~= nil then
                local rule = violation.rule or violation.ruleName or violation.engine or 'unknown'
                rule_counts[tostring(rule)] = (rule_counts[tostring(rule)] or 0) + 1
            end
        end
    end
    return critical_count, high_count, rule_counts
end

---Open the interactive pre-submission checklist.
function M.checklist()
    local state = load_state()
    vim.cmd(('botright %dnew'):format(CHECKLIST_HEIGHT))
    local bufnr = api.nvim_get_current_buf()
    api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
    api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
    api.nvim_set_option_value('swapfile', false, { buf = bufnr })
    -- wrap and linebreak are window-local: scope them to the new split.
    api.nvim_set_option_value('wrap', true, { win = 0 })
    api.nvim_set_option_value('linebreak', true, { win = 0 })
    api.nvim_buf_set_name(bufnr, 'sf-secreview-checklist')

    local lines, index = render_lines(state)
    api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    api.nvim_set_option_value('modifiable', false, { buf = bufnr })
    api.nvim_set_option_value('filetype', 'markdown', { buf = bufnr })

    local function toggle()
        local line_number = api.nvim_win_get_cursor(0)[1]
        local id = index[line_number]
        if id == nil then
            return
        end
        if state[id] then
            state[id] = nil
        else
            state[id] = true
        end
        save_state(state)
        local item = ITEM_BY_ID[id]
        local mark = state[id] and 'x' or ' '
        api.nvim_set_option_value('modifiable', true, { buf = bufnr })
        api.nvim_buf_set_lines(
            bufnr,
            line_number - 1,
            line_number,
            false,
            { ('- [%s] %s — %s'):format(mark, item.title, item.detail) }
        )
        api.nvim_set_option_value('modifiable', false, { buf = bufnr })
        local checked_count = 0
        for _ in pairs(state) do
            checked_count = checked_count + 1
        end
        core.notify(('Security review checklist: %d item(s) checked'):format(checked_count))
    end

    api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', { callback = toggle, desc = 'Toggle checklist item' })
    api.nvim_buf_set_keymap(bufnr, 'n', '<Space>', '', { callback = toggle, desc = 'Toggle checklist item' })
    api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>close<CR>', { desc = 'Close checklist' })
end

---Run the pre-submission gate: fail on any critical/high violation.
---@param opts? SfCommandArgs
function M.gate(opts)
    local target = resolve_target(opts)
    if target == 'force-app' then
        if not core.ensure({ project = true }) then
            return
        end
    elseif not core.ensure() then
        return
    end
    local output_path = fn.tempname() .. '.json'
    -- argv form: the target comes from the user but never touches a shell.
    local argv = {
        'sf',
        'code-analyzer',
        'run',
        '--workspace',
        target,
        '--severity-threshold',
        SEVERITY_THRESHOLD,
        '--output-file',
        output_path,
    }
    core.notify('Security review gate: scanning ' .. target .. ' (critical + high)…')
    vim.system(argv, { cwd = core.root(), text = true }, function(result)
        local file = io.open(output_path, 'rb')
        local content = file and file:read('*a') or nil
        if file then
            file:close()
        end
        pcall(uv.fs_unlink, output_path)
        vim.schedule(function()
            -- The CLI exits nonzero both on genuine failures AND when the
            -- severity threshold is exceeded. A parseable violations report
            -- means the scan ran: summarize it. Only a missing/unparseable
            -- report is a real execution failure.
            local ok, decoded = pcall(vim.json.decode, content or '')
            local ran = ok and type(decoded) == 'table' and type(decoded.violations) == 'table'
            if not ran then
                local message = result.stderr
                if type(message) ~= 'string' or message == '' then
                    message = result.stdout
                end
                if type(message) ~= 'string' or message == '' then
                    message = ('Salesforce Code Analyzer exited with status %d'):format(result.code)
                end
                core.notify(vim.trim(message), vim.log.levels.ERROR)
                return
            end
            local critical_count, high_count, rule_counts = summarize_gate(decoded)
            local failed = critical_count + high_count > 0
            -- Deterministic order: count desc, rule name asc.
            local ranked = {}
            for rule, count in pairs(rule_counts) do
                ranked[#ranked + 1] = { rule = rule, count = count }
            end
            table.sort(ranked, function(left, right)
                if left.count == right.count then
                    return left.rule < right.rule
                end
                return left.count > right.count
            end)
            local lines = {
                '# AgentExchange security review gate — ' .. target,
                '# Scanned ' .. os.date('%Y-%m-%d %H:%M') .. ' local time, severity threshold critical + high.',
                '',
                ('critical: %d | high: %d'):format(critical_count, high_count),
                failed and 'RESULT: FAIL — fix every critical/high violation before submitting.'
                    or 'RESULT: PASS — no critical/high violations found.',
                '',
                'Top rules:',
            }
            for position = 1, math.min(#ranked, TOP_RULES_MAX) do
                local entry = ranked[position]
                lines[#lines + 1] = ('  %dx %s'):format(entry.count, entry.rule)
            end
            lines[#lines + 1] = ''
            lines[#lines + 1] = 'Static analysis only — manual checklist items still apply (:SfSecReviewChecklist).'
            vim.cmd(('botright %dnew'):format(GATE_HEIGHT))
            local bufnr = api.nvim_get_current_buf()
            api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
            api.nvim_set_option_value('bufhidden', 'wipe', { buf = bufnr })
            api.nvim_set_option_value('swapfile', false, { buf = bufnr })
            api.nvim_set_option_value('wrap', true, { win = 0 })
            api.nvim_buf_set_name(bufnr, 'sf-secreview-gate')
            api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            api.nvim_set_option_value('modifiable', false, { buf = bufnr })
            api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<cmd>close<CR>', { desc = 'Close gate report' })
            if failed then
                core.notify(
                    ('Security gate FAILED: %d critical, %d high'):format(critical_count, high_count),
                    vim.log.levels.ERROR
                )
            else
                core.notify('Security gate PASSED: no critical/high violations')
            end
        end)
    end)
end

---Run Code Analyzer with the security-review preset: critical + high only.
---@param opts? SfCommandArgs
function M.scan(opts)
    local target = resolve_target(opts)
    if target == 'force-app' then
        if not core.ensure({ project = true }) then
            return
        end
    elseif not core.ensure() then
        return
    end
    core.open_term_cmd({
        'sf',
        'code-analyzer',
        'run',
        '--workspace',
        target,
        '--severity-threshold',
        SEVERITY_THRESHOLD,
        '--view',
        'table',
    }, TERMINAL_HEIGHT)
end

M.commands = {
    {
        name = 'SfSecReviewChecklist',
        fn = M.checklist,
        opts = { desc = 'Open the AgentExchange security review checklist', nargs = 0 },
    },
    {
        name = 'SfSecReviewGate',
        fn = M.gate,
        opts = {
            complete = 'dir',
            desc = 'Run the pre-submission gate: fail on any critical/high violation',
            nargs = '?',
        },
    },
    {
        name = 'SfSecReviewScan',
        fn = M.scan,
        opts = {
            complete = 'file',
            desc = 'Scan with the security preset (critical + high severities)',
            nargs = '?',
        },
    },
}

return M
