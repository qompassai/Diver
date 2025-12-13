-- /qompassai/Diver/lsp/uv.lua
-- Qompass AI UV LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------
-- cargo install --git https://codeberg.org/caradhras/uvls --locked
vim.cmd([[au BufRead,BufNewFile *.uvl setfiletype uvl]])
vim.lsp.config['uv_ls'] = {
    cmd = {
        'uvls',
    },
    filetypes = {
        'uvl',
    },
    root_markers = {
        '.git',
    },
}
