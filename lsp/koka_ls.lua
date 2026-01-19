-- /qompassai/Diver/lsp/koka_ls.lua
-- Qompass AI Diver Koka LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'koka',
        '--language-server',
        '--lsstdio',
    },
    filetypes = {
        'koka',
    },
    root_markers = {
        '.git',
    },
}