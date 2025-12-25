-- /qompassai/Diver/lsp/alloy_ls.lua
-- Qompass AI Alloy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'alloy',
        'lsp',
    },
    filetypes = {
        'alloy',
    },
    root_markers = {
        '.git',
    },
}
