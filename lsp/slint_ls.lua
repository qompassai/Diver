-- /qompassai/Diver/lsp/slint_ls.lua
-- Qompass AI Slint (formerly SixyFPS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.cmd([[ autocmd BufRead,BufNewFile *.slint set filetype=slint ]])
vim.lsp.config['slint_ls'] = {
    cmd = {
        'slint-lsp',
    },
    filetypes = {
        'slint',
    },
    root_markers = {
        '.git',
    },
}
