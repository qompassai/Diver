-- /qompassai/Diver/lftdetect/supercollider.lua
-- Qompass AI Diver FtDetect Supercollider Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
if vim.g.do_filetype_lua == 0 then
    vim.api.nvim_create_autocmd({
        'BufRead',
        'BufNewFile',
        'BufWinEnter',
        'BufEnter',
    }, {
        pattern = { '*.schelp' },
        callback = function(ev)
            vim.bo[ev.buf].filetype = 'scdoc'
        end,
    })
end
