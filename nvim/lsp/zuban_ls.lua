-- /qompassai/Diver/lsp/zuban_ls.lua
-- Qompass AI Diver Zuban LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'zuban',
        'server',
    },
    filetypes = {
        'python',
    },
    root_markers = {
        '.git',
        'pyproject.toml',
        'Pipfile',
        'requirements.txt',
        'setup.py',
        'setup.cfg',
    },
}
