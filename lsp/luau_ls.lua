-- /qompassai/Diver/lsp/luau_ls.lua
-- Qompass AI Diver Luau LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
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
    settings = {},
}