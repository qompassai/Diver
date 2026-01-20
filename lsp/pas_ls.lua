-- /qompassai/Diver/lsp/pas_ls.lua
-- Qompass AI Diver Pascal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pasls',
    },
    filetypes = {
        'pascal',
    },
    root_markers = {
        '*.lpi',
        '*.lpk',
        '.git',
    },
    settings = {},
}