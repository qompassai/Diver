-- /qompassai/Diver/lsp/c3_ls.lua
-- Qompass AI C3 LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.cmd([[autocmd BufNewFile,BufRead *.c3 set filetype=c3]])
---@type vim.lsp.Config
return {
    cmd = {
        'c3lsp',
    },
    filetypes = {
        'c3',
        'c3i',
    },
    root_markers = {
        '.git',
        'c3.toml',
    },
    settings = {
        ...,
    },
}
