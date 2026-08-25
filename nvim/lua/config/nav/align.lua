-- /qompassai/Diver/lua/config/nav/align.lua
-- Qompass AI Diver Align Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local align_pattern = [[^\(\s*---@\S\+\s\+\S\+\)\s\+\(.*\)$]]
vim.api.nvim_create_user_command('AlignAnno', function(opts)
    local col = tonumber(opts.fargs[1]) or 60
    local width = col - 1
    local fmt = '%-' .. width .. 's %s'
    local repl = ([[\=printf('%s', submatch(1), submatch(2))]]):format(fmt)
    local cmd = ('%d,%ds/%s/%s/'):format(opts.line1, opts.line2, align_pattern, repl)
    vim.cmd(cmd)
end, {
    nargs = 1,
    range = true,
})