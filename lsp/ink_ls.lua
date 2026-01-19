-- /qompassai/Diver/lsp/ink_ls.lua
-- Qompass AI Ink LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'ink-lsp-server',
    },
    filetypes = {
        'rust',
        'ink',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}