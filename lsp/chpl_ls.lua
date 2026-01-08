-- /qompassai/Diver/lsp/chpl_ls.lua
-- Qompass AI Diver Chapel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'chpl-language-server',
        'chplcheck',
    },
    filetypes = {
        'chpl',
    },
    root_markers = {
        'chpl-language-server.cfg',
        '.chpl-language-server.cfg',
        '.cls-commands.json',
        '.cls-commands.jsonc',
        '.git',
        'Mason.toml',
    },
    settings = {},
}