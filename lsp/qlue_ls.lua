-- /qompassai/Diver/lsp/qlue_ls.lua
-- Qompass AI Qlue LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'qlue-ls',
        'server',
    },
    filetypes = {
        'sparql',
    },
    root_markers = {},
    settings = {},
}
