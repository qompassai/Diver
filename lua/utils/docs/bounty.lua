-- bounty.lua
-- Qompass AI Diver Bounty Docs Utils
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local function slugify(str)
    return str:lower():gsub('[^a-z0-9]+', '-'):gsub('^-+', ''):gsub('-+$', '')
end
local function ensure_dir(path)
    vim.fn.mkdir(path, 'p')
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

    local base = vim.fn.expand('~/security/bugbounties')
    local prog_dir = base .. '/programs'
    ensure_dir(prog_dir)

    local fname = prog_dir .. '/' .. platform .. '-' .. slugify(name) .. '.md'
    if vim.loop.fs_stat(fname) then
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

    local base = vim.fn.expand('~/security/bugbounties')
    local report_dir = base .. '/reports'
    ensure_dir(report_dir)

    local slug = title:lower():gsub('[^a-z0-9]+', '-'):gsub('^-+', ''):gsub('-+$', '')
    local fname = ('%s/%s-%s-%s-%s.md'):format(report_dir, today(), platform, program, slug)

    if vim.loop.fs_stat(fname) then
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

return M

--[[

local bounty_reports = require("bounty.reports")

vim.api.nvim_create_user_command("BountyReportNew", function()
  bounty_reports.new_report()
end, { desc = "Create/open bug bounty report file" })
vim.api.nvim_create_user_command("BountyIndex", function()
  local base = vim.fn.expand("~/security/bugbounties")
  local programs = vim.fn.glob(base .. "/programs/*.md", false, true)
  local reports  = vim.fn.glob(base .. "/reports/*.md", false, true)

  local buf = vim.api.nvim_create_buf(false, true)
  local lines = { "# Bug Bounty Index", "" }

  table.insert(lines, "## Programs")
  for _, p in ipairs(programs) do
    table.insert(lines, "- " .. vim.fn.fnamemodify(p, ":t"))
  end

  table.insert(lines, "")
  table.insert(lines, "## Reports")
  for _, r in ipairs(reports) do
    table.insert(lines, "- " .. vim.fn.fnamemodify(r, ":t"))
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
end, { desc = "List bounty programs and reports" })
local bounty_programs = require("bounty.programs")

vim.api.nvim_create_user_command("BountyProgramNew", function()
  bounty_programs.new_program()
end, { desc = "Create/open bug bounty program file" })
--]]
