-- /qompassai/Diver/lua/utils/ddx.lua
-- Qompass AI Diver Util Differential Diagnosis (DDX) config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
vim.api.nvim_create_user_command('ConfigSelfCheck', function()
    require('tests.selfcheck').run()
end, {})
local function strip_ansi()
    vim.cmd([[%s/[\x1b]\[[0-9;]*m//g]])
end
vim.api.nvim_create_autocmd('BufReadPost', {
    pattern = '*',
    callback = function()
        if vim.bo.filetype == 'nvimpager' then
            strip_ansi()
        end
    end,
})
