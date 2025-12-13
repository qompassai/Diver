-- /qompassai/Diver/lsp/nickel_ls.lua
-- Qompass AI Nickel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/tweag/nickel
-- cargo install nickel-lang-lsp
vim.lsp.config['nickel_ls'] = {
    cmd = {
        'nls',
    },
    filetypes = {
        'ncl',
        'nickel',
    },
    root_markers = {
        '.git',
    },
}
