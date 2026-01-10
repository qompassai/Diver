-- /qompassai/Diver/lsp/regal_ls.lua
-- Qompass AI Regal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'regal',
        'language-server',
    },
    filetypes = {
        'rego',
    },
    root_markers = {
        '.git',
    },
    settings = {
        regal = {
            formatter = 'regal fix',
        },
    },
}