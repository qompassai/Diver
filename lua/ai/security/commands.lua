-- /qompassai/Diver/lua/ai/security/commands.lua
-- Qompass AI Security User Commands (Tiger Style)
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- The user-facing surface of the security scanner: AiScan shows a
-- scan report for a file in a scratch buffer, AiQuarantine moves a
-- suspicious file out of the way. Requiring this module registers
-- the commands; it starts nothing and scans nothing.

local api = vim.api

---@param args string Raw command arguments
---@return string path Expanded target path, '' when none resolves
local function resolve_target(args)
    if args ~= '' then
        return vim.fn.expand(args)
    end
    local cfile = vim.fn.expand('<cfile>')
    if cfile ~= '' then
        return cfile
    end
    return api.nvim_buf_get_name(0)
end

---@param path string
---@param report SecurityReport
local function show_report(path, report)
    local lines = {
        'Security scan: ' .. path,
        'Verdict: ' .. report.verdict,
        '',
    }
    if #report.findings == 0 then
        lines[#lines + 1] = 'No findings.'
    end
    for _, finding in ipairs(report.findings) do
        local offset = finding.offset and (' @' .. tostring(finding.offset)) or ''
        lines[#lines + 1] = ('[%s] %s%s'):format(finding.severity, finding.code, offset)
        lines[#lines + 1] = '  ' .. finding.detail
    end
    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].swapfile = false
    api.nvim_command('botright split')
    api.nvim_win_set_buf(0, buf)
end

api.nvim_create_user_command('AiScan', function(command)
    local path = resolve_target(command.args)
    if path == '' then
        vim.notify('AiScan: no file under cursor or in buffer', vim.log.levels.ERROR)
        return
    end
    local report, err = require('ai.security').scan_file(path)
    if report == nil then
        vim.notify('AiScan failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    show_report(path, report)
end, {
    nargs = '?',
    complete = 'file',
    desc = 'Scan a file for prompt-injection / malware markers before AI use',
})

api.nvim_create_user_command('AiQuarantine', function(command)
    local path = resolve_target(command.args)
    if path == '' then
        vim.notify('AiQuarantine: no file under cursor or in buffer', vim.log.levels.ERROR)
        return
    end
    local dest, err = require('ai.security').quarantine(path)
    if dest == nil then
        vim.notify('AiQuarantine failed: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    vim.notify('Quarantined to ' .. dest, vim.log.levels.WARN)
end, {
    nargs = '?',
    complete = 'file',
    desc = 'Move a suspicious file into the security quarantine directory',
})

return true
