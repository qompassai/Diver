-- bounty/init.lua
-- Bug-bounty workflow: docs utils plus the staged pipeline.
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
--
-- Plain language: this is the front door of the bug-bounty workflow. The
-- docs helpers (program notes, report drafts) live here, and the pipeline
-- stages live in submodules: scope (permission slips), recon (knocking on
-- doors), gates (human approvals), report (writing it up), submit (sending
-- it). Call require('security.bounty').setup() once to get the :Bounty*
-- commands.
---@module 'security.bounty'

local gates = require('security.bounty.gates')
local scope = require('security.bounty.scope')
local recon = require('security.bounty.recon')
local report = require('security.bounty.report')
local submit = require('security.bounty.submit')
local profiles = require('security.bounty.profiles')

local M = {}

M.gates = gates
M.scope = scope
M.recon = recon
M.report = report
M.submit = submit
M.profiles = profiles

---Base directory for all bug-bounty working files.
---@return string
function M.basedir()
    return vim.fn.expand('~/security/bugbounties')
end

local function slugify(str)
    return str:lower():gsub('[^a-z0-9]+', '-'):gsub('^-+', ''):gsub('-+$', '')
end

local function ensure_dir(path)
    vim.fn.mkdir(path, 'p')
end

---Show lines in a scratch vsplit. Shared by read-only viewers.
---@param lines string[]
---@param filetype? string
local function show_lines(lines, filetype)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    if filetype ~= nil then
        vim.bo[buf].filetype = filetype
    end
    vim.cmd('vsplit')
    vim.api.nvim_win_set_buf(0, buf)
end

function M.new_program()
    local platform = vim.fn.input('Platform (e.g. hackerone, bugcrowd): ')
    if platform == '' then
        return
    end
    local name = vim.fn.input('Program name/slug (e.g. example.com): ')
    if name == '' then
        return
    end

    local prog_dir = M.basedir() .. '/programs'
    ensure_dir(prog_dir)

    local fname = prog_dir .. '/' .. slugify(platform) .. '-' .. slugify(name) .. '.md'
    if vim.uv.fs_stat(fname) then
        vim.cmd('edit ' .. vim.fn.fnameescape(fname))
        return
    end

    local lines = {
        '# ' .. name .. ' (' .. platform .. ')',
        '',
        '## Program URL',
        '- ',
        '',
        '## Scope',
        '- In scope:',
        '  - ',
        '- Out of scope:',
        '  - ',
        '',
        '## Rules / Important Notes',
        '- ',
        '',
        '## Rewards / Severity',
        '- ',
        '',
        '## Notes',
        '- ',
    }

    ensure_dir(vim.fn.fnamemodify(fname, ':h'))
    vim.fn.writefile(lines, fname)
    vim.cmd('edit ' .. vim.fn.fnameescape(fname))
end

local function today()
    return os.date('%Y-%m-%d')
end

function M.new_report()
    local platform = vim.fn.input('Platform (e.g. hackerone): ')
    if platform == '' then
        return
    end
    local program = vim.fn.input('Program slug (e.g. example.com): ')
    if program == '' then
        return
    end
    local title = vim.fn.input('Short finding title (e.g. XSS in search): ')
    if title == '' then
        return
    end
    local report_dir = M.basedir() .. '/reports'
    ensure_dir(report_dir)

    local slug = slugify(title)
    local fname = ('%s/%s-%s-%s-%s.md'):format(report_dir, today(), slugify(platform), slugify(program), slug)

    if vim.uv.fs_stat(fname) then
        vim.cmd('edit ' .. vim.fn.fnameescape(fname))
        return
    end

    local lines = {
        '# ' .. title,
        '',
        '- Platform: ' .. platform,
        '- Program: ' .. program,
        '- Date: ' .. today(),
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
    }

    ensure_dir(vim.fn.fnamemodify(fname, ':h'))
    vim.fn.writefile(lines, fname)
    vim.cmd('edit ' .. vim.fn.fnameescape(fname))
end

---Scaffold the working directory tree. Idempotent.
function M.scaffold()
    for _, sub in ipairs({ 'programs', 'reports', 'scope', 'recon', 'gates', 'findings' }) do
        ensure_dir(M.basedir() .. '/' .. sub)
    end
end

local setup_done = false

---Create the :Bounty* commands. Idempotent: safe to call twice.
function M.setup()
    if setup_done then
        return M
    end
    M.scaffold()

    vim.api.nvim_create_user_command('BountyScope', function(opts)
        local platform = opts.args ~= '' and opts.args or vim.fn.input('Platform (h1/bc/it/ywh/immunefi): ')
        if platform == '' then
            return
        end
        local program = vim.fn.input('Program slug to file scope under (e.g. h1-cloudflare): ')
        if program == '' then
            return
        end
        local entries = scope.poll(platform, { bbp_only = true })
        local path = scope.save(program, entries)
        vim.notify(('BountyScope: %d targets filed to %s'):format(#entries, path))
    end, { nargs = '?', desc = 'Poll bbscope and file program scope (public, paid programs only)' })

    vim.api.nvim_create_user_command('BountyRecon', function(opts)
        local program = opts.args ~= '' and opts.args or vim.fn.input('Program slug: ')
        if program == '' then
            return
        end
        local id = recon.run(program)
        vim.notify('BountyRecon: run ' .. id .. ' started (see :BountyReconStatus)')
    end, { nargs = '?', desc = 'Run the recon chain (REQUIRES open scope gate)' })

    vim.api.nvim_create_user_command('BountyReconStatus', function()
        local lines = recon.status()
        if #lines == 0 then
            vim.notify('BountyRecon: no runs yet')
            return
        end
        vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, { desc = 'Show recon run states' })

    vim.api.nvim_create_user_command('BountyReconCancel', function(opts)
        recon.cancel(opts.args)
    end, { nargs = 1, desc = 'Cancel a recon run' })

    vim.api.nvim_create_user_command('BountyReport', function(opts)
        local platform = vim.fn.input('Platform (hackerone/bugcrowd/intigriti/yeswehack/immunefi): ')
        if platform == '' then
            return
        end
        local program = vim.fn.input('Program slug: ')
        if program == '' then
            return
        end
        local finding = vim.fn.input('Validated finding slug: ')
        if finding == '' then
            return
        end
        local title = vim.fn.input('Report title: ')
        if title == '' then
            return
        end
        report.new(platform, program, finding, title)
    end, { desc = 'Generate a report from a validated finding (REQUIRES open finding gate)' })

    vim.api.nvim_create_user_command('BountySubmit', function(opts)
        local path = opts.args ~= '' and opts.args or vim.fn.input('Report file: ', M.basedir() .. '/reports/', 'file')
        if path == '' then
            return
        end
        submit.submit(vim.fn.expand(path))
    end, {
        nargs = '?',
        complete = 'file',
        desc = 'Preview the exact submission payload (REQUIRES open submission gate; never auto-sends)',
    })

    vim.api.nvim_create_user_command('BountyApprove', function(opts)
        local kind, target = opts.args:match('^(%S+)%s+(%S+)$')
        if kind == nil then
            vim.notify(
                'Usage: :BountyApprove <scope|finding|submission> <program-or-finding-slug>',
                vim.log.levels.ERROR
            )
            return
        end
        if kind == 'scope' then
            -- A program profile is active: the scope-gate request must pass
            -- the profile's load-bearing rules (class-based scope, per-target
            -- operator confirmation, vendor hard-block) BEFORE the gate may
            -- open. Refusal leaves the gate closed.
            local profile_name = profiles.active()
            if profile_name ~= nil then
                local ok, problems = profiles.validate_scope_request(profile_name, target)
                if not ok then
                    vim.notify(
                        ("BountyApprove: scope gate REFUSED under profile '%s'"):format(profile_name),
                        vim.log.levels.ERROR
                    )
                    for _, problem in ipairs(problems) do
                        vim.notify('  - ' .. problem, vim.log.levels.ERROR)
                    end
                    return
                end
            end
        end
        local note = vim.fn.input('Approval note (optional): ')
        local path = gates.approve(kind, target, note ~= '' and note or nil)
        vim.notify(('Gate %s opened for %s (%s)'):format(kind, target, path))
    end, { nargs = 1, desc = 'Operator approval: open a gate (scope|finding|submission)' })

    vim.api.nvim_create_user_command('BountyIndex', function()
        local base = M.basedir()
        local programs = vim.fn.glob(base .. '/programs/*.md', false, true)
        local reports = vim.fn.glob(base .. '/reports/*.md', false, true)
        local lines = { '# Bug Bounty Index', '' }
        lines[#lines + 1] = '## Programs'
        for _, p in ipairs(programs) do
            lines[#lines + 1] = '- ' .. vim.fn.fnamemodify(p, ':t')
        end
        lines[#lines + 1] = ''
        lines[#lines + 1] = '## Reports'
        for _, r in ipairs(reports) do
            lines[#lines + 1] = '- ' .. vim.fn.fnamemodify(r, ':t')
        end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].buftype = 'nofile'
        vim.bo[buf].bufhidden = 'wipe'
        vim.bo[buf].swapfile = false
        vim.cmd('vsplit')
        vim.api.nvim_win_set_buf(0, buf)
    end, { desc = 'List bounty programs and reports' })

    vim.api.nvim_create_user_command('BountyTools', function()
        local lines = { '# Recon tool availability', '' }
        for tool, ok in pairs(recon.available()) do
            lines[#lines + 1] = ('- [%s] %s'):format(ok and 'x' or ' ', tool)
        end
        vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
    end, { desc = 'Show which recon tools are on PATH' })

    vim.api.nvim_create_user_command('BountyDashboard', function()
        require('security.bounty.dashboard').show()
    end, { desc = 'Render the bug-bounty dashboard PNG and preview it' })

    vim.api.nvim_create_user_command('BountyProfile', function(opts)
        -- Read-only viewing path: show/list never open gates, never scan,
        -- never touch the network. 'use' only selects the rulebook that
        -- later scope-gate and recon checks enforce; it approves nothing.
        local sub, rest = opts.args:match('^(%S+)%s*(.-)%s*$')
        if sub == nil or sub == '' then
            local active = profiles.active()
            if active ~= nil then
                sub, rest = 'show', active
            else
                sub, rest = 'list', ''
            end
        end
        if sub == 'list' then
            local lines = { '# Program profiles (read-only rulebooks)', '' }
            for _, name in ipairs(profiles.list()) do
                local p = profiles.get(name)
                local marker = profiles.active() == name and ' [active]' or ''
                lines[#lines + 1] = ('- %s: %s%s'):format(name, p.display_name, marker)
            end
            vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO)
        elseif sub == 'show' then
            local name = rest ~= '' and rest or profiles.active()
            if name == nil or name == '' then
                vim.notify('Usage: :BountyProfile show <name>', vim.log.levels.ERROR)
                return
            end
            local lines, err = profiles.render(name)
            if lines == nil then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            show_lines(lines, 'markdown')
        elseif sub == 'use' then
            if rest == '' then
                vim.notify('Usage: :BountyProfile use <name>', vim.log.levels.ERROR)
                return
            end
            local ok, err = profiles.set(rest)
            if not ok then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            vim.notify(
                ("BountyProfile: '%s' is now the active profile. This is NOT an approval: no gate was opened and no scanning was started."):format(
                    rest
                )
            )
        elseif sub == 'clear' then
            if profiles.clear() then
                vim.notify('BountyProfile: active profile cleared')
            else
                vim.notify('BountyProfile: no profile was active')
            end
        elseif sub == 'confirm' then
            local program, target = rest:match('^(%S+)%s+(%S+)$')
            if program == nil then
                vim.notify('Usage: :BountyProfile confirm <program> <target>', vim.log.levels.ERROR)
                return
            end
            local ok, err = profiles.confirm_target(program, target)
            if not ok then
                vim.notify(err, vim.log.levels.ERROR)
                return
            end
            vim.notify(
                ("BountyProfile: operator confirmed '%s' for '%s' -- attested publicly accessible and DoD-owned/operated/controlled; not a vendor or non-DoD system."):format(
                    target,
                    program
                )
            )
        else
            vim.notify(
                'Usage: :BountyProfile [list|show <name>|use <name>|clear|confirm <program> <target>]',
                vim.log.levels.ERROR
            )
        end
    end, { nargs = '*', desc = 'View/select program profiles (read-only; never opens gates)' })

    setup_done = true
    return M
end

return M
