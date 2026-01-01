-- /qompassai/Diver/lsp/chpl_ls.lua
-- Qompass AI Diver Chapel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = { 'chpl-language-server', 'chplcheck' },
    filetypes = {
        'chpl',
    },
    root_markers = {
        '.cls-commands.json',
        '.cls-commands.jsonc',
        'Mason.toml',
        'chpl-language-server.cfg',
        '.chpl-language-server.cfg',
        '.git',
    },
    settings = {},
}
