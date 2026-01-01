-- /qompassai/Diver/lsp/debputy_ls.lua
-- Qompass AI Diver Debputy LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'debputy',
        'lsp',
        'server',
    },
    filetypes = {
        'autopkgtest',
        'debcontrol',
        'debcopyright',
        'debchangelog',
        'make',
        'yaml',
    },
    root_markers = {
        'debian',
    },
}
