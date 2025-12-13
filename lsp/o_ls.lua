-- /qompassai/Diver/lsp/o_ls.lua
-- Qompass AI Odin LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference: https://github.com/DanielGavin/ols
vim.lsp.config['o_ls'] = {
    cmd = {
        'ols',
    },
    filetypes = {
        'odin',
    },
    root_markers = {
        '.git',
        'ols.json',
        'ols.jsonc',
        '*.odin',
    },
}
