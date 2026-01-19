-- /qompassai/Diver/lsp/pact_ls.lua
-- Qompass AI Diver Pact LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'pact-lsp',
    },
    filetypes = {
        'pact',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}