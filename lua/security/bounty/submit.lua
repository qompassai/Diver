-- submit.lua
--
-- Submission: build the exact payload and show it. Never auto-submits.
--
-- Plain language: sending a report is the point of no return. This module
-- builds EXACTLY what would be sent, shows it to you, and stops. You paste
-- it into the platform yourself. API submission is a later phase; today the
-- module walks you through manual submission with the payload in hand.
--
-- Guardrail (proposal section 11.2): no auto-submit, ever. YesWeHack bans
-- accounts for AI slop and Immunefi buries bad validity ratios, so every
-- submission is operator-approved with the exact payload shown first.
---@module 'security.bounty.submit'

local gates = require('security.bounty.gates')
local report = require('security.bounty.report')

local M = {}

---Report filename -> finding slug. Reports are named
---<date>-<platform>-<program>-<slug>.md by report.new.
---@param path string
---@return string slug
local function report_slug(path)
    local base = vim.fn.fnamemodify(path, ':t:r')
    local slug = base:match('^%d%d%d%d%-%d%d%-%d%d%-[^%-]+%-[^%-]+%-(.+)$')
    assert(slug ~= nil, 'submit: cannot parse finding slug from report filename: ' .. path)
    return slug
end

---Parse a report file into the submission payload: the exact fields the
---operator will paste into the platform form.
---@param path string Report file.
---@return { platform: string, program: string, title: string, severity: string, body: string }
function M.payload(path)
    assert(vim.uv.fs_stat(path) ~= nil, 'submit.payload: report not found: ' .. tostring(path))
    local lines = vim.fn.readfile(path)
    local text = table.concat(lines, '\n')
    local function field(name)
        return text:match('%- ' .. name .. ': ([^\n]*)') or ''
    end
    local title = lines[1]:match('^# (.*)$') or ''
    assert(title ~= '', 'submit.payload: report has no title')
    local platform = field('Platform')
    assert(platform ~= '', 'submit.payload: report has no Platform field')
    return {
        platform = platform,
        program = field('Program'),
        title = title,
        severity = field('Severity'),
        body = text,
    }
end

---Manual submission checklist per platform.
---@param platform string
---@return string[]
function M.checklist(platform)
    local steps = {
        '1. Run :BountyApprove submission <finding-slug> (operator approval).',
        '2. Open the program page and start a new report.',
        '3. Paste the payload sections below into the matching form fields.',
        '4. Attach PoC files / screenshots referenced in the report.',
        '5. Re-read the preview once more, then submit.',
    }
    if platform == 'intigriti' then
        steps[#steps + 1] = '6. Intigriti: confirm no PII in evidence (GDPR).'
    elseif platform == 'immunefi' then
        steps[#steps + 1] = '6. Immunefi: confirm $ impact is quantified; validity ratio matters.'
    elseif platform == 'yeswehack' then
        steps[#steps + 1] = '6. YesWeHack: final duplicate search before sending.'
    end
    return steps
end

---Show the exact submission payload in a scratch buffer. No gate required:
---seeing the payload is what the operator approves.
---@param path string Report file.
function M.preview(path)
    local p = M.payload(path)
    local lint = report.lint(path)
    local lines = {
        '# Submission preview -- NOTHING HAS BEEN SENT',
        '',
        ('Platform: %s'):format(p.platform),
        ('Program:  %s'):format(p.program),
        ('Title:    %s'):format(p.title),
        ('Severity: %s'):format(p.severity),
        '',
        lint.ok and 'Checklist lint: PASS' or 'Checklist lint: FAIL',
    }
    if not lint.ok then
        for _, issue in ipairs(lint.issues) do
            lines[#lines + 1] = '  - ' .. issue
        end
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '## Manual submission steps'
    for _, step in ipairs(M.checklist(p.platform)) do
        lines[#lines + 1] = step
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = '## Payload body (paste into the platform form)'
    lines[#lines + 1] = ''
    for line in p.body:gmatch('[^\n]+') do
        lines[#lines + 1] = line
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'markdown'
    vim.cmd('vsplit')
    vim.api.nvim_win_set_buf(0, buf)
end

---Walk the operator through manual submission. Requires the submission
---gate: this is the point of no return.
---@param path string Report file.
function M.submit(path)
    local slug = report_slug(path)
    assert(
        gates.is_open('submission', slug),
        "submit: submission gate is CLOSED for '"
            .. slug
            .. "' -- approve first (:BountyApprove submission "
            .. slug
            .. ')'
    )
    M.preview(path)
    vim.notify(
        'Manual submission: copy the payload above into the platform form. '
            .. 'API submission is a later phase; nothing was sent automatically.',
        vim.log.levels.WARN
    )
end

return M
