-- /qompassai/Diver/lsp/ziggy.lua
-- Qompass AI Ziggy LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'ziggy',
        'lsp',
    },
    filetypes = {
        'ziggy',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}