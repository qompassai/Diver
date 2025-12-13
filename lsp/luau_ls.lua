-- /qompassai/Diver/lsp/luau_ls.lua
-- Qompass AI Luau LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/JohnnyMorganz/luau-lsp
vim.lsp.config['luau-lsp'] = {
    cmd = {
        'luau-lsp',
        'lsp',
    },
    filetypes = {
        'luau',
    },
    root_markers = {
        '.git',
    },
}
