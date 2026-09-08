-- /qompassai/diver/lsp/jedi_ls.lua
-- Qompass AI Diver Jedi LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

return ---@type vim.lsp.Config
{
    cmd = {
        'jedi-language-server',
    },
    filetypes = {
        'python',
    },
    root_markers = {
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'requirements.txt',
        'Pipfile',
        '.git',
    },
}
