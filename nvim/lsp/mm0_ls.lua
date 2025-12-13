-- /qompassai/Diver/lsp/mm0_ls.lua
-- Qompass AI MetaMath Zero (mm0) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://github.com/digama0/mm0/tree/master/mm0-rs)
-- cargo install --git https://github.com/digama0/mm0 --locked mm0-rs
vim.lsp.config['mm0_ls'] = {
    cmd = {
        'mm0-rs',
        'server',
    },
    root_markers = {
        '.git',
    },
    filetypes = {
        'metamath-zero',
    },
}
