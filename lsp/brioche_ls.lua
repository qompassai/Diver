-- /qompassai/Diver/lsp/brioche_ls.lua
-- Qompass AI Brioche LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'brioche',
        'lsp',
    },
    filetypes = {
        'brioche',
    },
    root_markers = {
        'project.bri',
    },
}
