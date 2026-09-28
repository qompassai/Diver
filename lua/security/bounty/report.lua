-- report.lua
--
-- Report generation: validated findings become per-platform Markdown reports.
--
-- Plain language: a good bug report has the same skeleton every time -- what
-- you found, why it matters, how to reproduce it. This module fills that
-- skeleton for each platform's preferred shape, then runs a 60-second
-- checklist over the result before you send it anywhere.
--
-- A report is generated from a VALIDATED finding: the finding gate must be
-- open for the finding slug (see gates.lua). Reports live under
-- ~/security/bugbounties/reports/.
---@module 'security.bounty.report'

local gates = require('security.bounty.gates')

local M = {}

---Platforms with report templates.
M.platforms = { 'hackerone', 'bugcrowd', 'intigriti', 'yeswehack', 'immunefi' }

---@param platform string
---@return boolean
local function valid_platform(platform)
    for _, p in ipairs(M.platforms) do
        if p == platform then
            return true
        end
    end
    return false
end

---Per-platform notes appended to the template. These are the platform
---quirks that get reports rejected when ignored.
---@param platform string
---@return string[]
local function platform_notes(platform)
    if platform == 'hackerone' then
        return {
            '> HackerOne: fill the Weakness field on the submission form to match',
            '> the vulnerability class below. Keep repro steps numbered and atomic.',
        }
    elseif platform == 'yeswehack' then
        return {
            '> YesWeHack: search existing reports first -- duplicates are rejected',
            '> fast and hurt your reputation. Human confirmation required.',
        }
    elseif platform == 'intigriti' then
        return {
            '> Intigriti: GDPR applies -- strip ALL personal data from evidence',
            '> (emails, IPs of third parties, session tokens of other users).',
        }
    elseif platform == 'immunefi' then
        return {
            '> Immunefi: quantify impact in $ terms and attach a working PoC',
            '> (Foundry test preferred for smart contracts). Invalid reports',
            '> damage your validity ratio -- submit sparingly.',
        }
    else
        return {
            '> BugCrowd: match the program brief\'s priority guidance; note any',
            '> researcher-specific submission instructions in the brief.',
        }
    end
end

---Required Markdown sections every report must contain.
M.required_sections = {
    '## Summary',
    '## Impact',
    '### Steps to Reproduce',
    '### Proof of Concept',
}

---Map a CVSS v3 score to a severity label.
---@param cvss number 0.0 - 10.0
---@return string severity One of critical/high/medium/low/none.
function M.severity(cvss)
    assert(type(cvss) == 'number' and cvss >= 0 and cvss <= 10, 'report.severity: cvss must be 0-10')
    if cvss >= 9.0 then
        return 'critical'
    elseif cvss >= 7.0 then
        return 'high'
    elseif cvss >= 4.0 then
        return 'medium'
    elseif cvss > 0 then
        return 'low'
    else
        return 'none'
    end
end

---Build the template lines for a report.
---@param platform string
---@param program string
---@param finding string Validated finding slug.
---@param title string Report title.
---@return string[] lines
local function template(platform, program, finding, title)
    local lines = {
        '# ' .. title,
        '',
        '- Platform: ' .. platform,
        '- Program: ' .. program,
        '- Finding: ' .. finding,
        '- Date: ' .. os.date('%Y-%m-%d'),
        '- Severity:  (CVSS: )',
        '',
        '## Summary',
        '',
        '## Impact',
        '',
        '## Affected Assets',
        '- ',
        '',
        '## Vulnerability Details',
        '',
        '### Steps to Reproduce',
        '1. ',
        '2. ',
        '3. ',
        '',
        '### Proof of Concept',
        '```http',
        '```',
        '',
        '## Remediation',
        '',
        '## References',
        '- ',
        '',
    }
    for _, note in ipairs(platform_notes(platform)) do
        lines[#lines + 1] = note
    end
    return lines
end

---Create a report file from the platform template and open it.
---Requires the finding gate to be open for `finding`.
---@param platform string One of M.platforms.
---@param program string Program slug.
---@param finding string Validated finding slug (path-safe).
---@param title string Report title.
---@return string path The report file written.
function M.new(platform, program, finding, title)
    assert(valid_platform(platform), "report.new: unknown platform '" .. tostring(platform) .. "'")
    assert(type(program) == 'string' and program ~= '', 'report.new: program must be nonempty')
    assert(
        program:match('^[A-Za-z0-9_%.%-]+$'),
        'report.new: program must be path-safe (letters, digits, _, ., -)'
    )
    assert(
        finding:match('^[A-Za-z0-9_%.%-]+$'),
        'report.new: finding must be path-safe (letters, digits, _, ., -)'
    )
    assert(type(title) == 'string' and title ~= '', 'report.new: title must be nonempty')
    assert(
        gates.is_open('finding', finding),
        "report.new: finding gate is CLOSED for '" .. finding .. "' -- validate the finding first (:BountyApprove finding " .. finding .. ')'
    )
    local dir = vim.fn.expand('~/security/bugbounties/reports')
    vim.fn.mkdir(dir, 'p')
    local slug = title:lower():gsub('[^a-z0-9]+', '-'):gsub('^-+', ''):gsub('-+$', '')
    local path = ('%s/%s-%s-%s-%s.md'):format(dir, os.date('%Y-%m-%d'), platform, program, slug)
    if vim.uv.fs_stat(path) == nil then
        vim.fn.writefile(template(platform, program, finding, title), path)
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
    return path
end

---The 60-second checklist: mechanical checks that catch the reports
---triagers reject on sight.
---@param path string Report file.
---@return { ok: boolean, issues: string[] }
function M.lint(path)
    assert(type(path) == 'string', 'report.lint: path must be a string')
    local issues = {}
    if vim.uv.fs_stat(path) == nil then
        return { ok = false, issues = { 'file does not exist: ' .. path } }
    end
    local text = table.concat(vim.fn.readfile(path), '\n')
    if not text:match('^# %S') then
        issues[#issues + 1] = 'missing title (# ...)'
    end
    for _, section in ipairs(M.required_sections) do
        if not text:find(section, 1, true) then
            issues[#issues + 1] = 'missing section: ' .. section
        end
    end
    if text:match('### Proof of Concept\n```%w*\n```') then
        issues[#issues + 1] = 'Proof of Concept block is empty'
    end
    if not text:match('%- Severity: %S') then
        issues[#issues + 1] = 'severity not filled in (- Severity:)'
    end
    for _, placeholder in ipairs({ 'TODO', 'FIXME', '<fill', 'XXX' }) do
        if text:find(placeholder, 1, true) then
            issues[#issues + 1] = "leftover placeholder: '" .. placeholder .. "'"
            break
        end
    end
    return { ok = #issues == 0, issues = issues }
end

return M
