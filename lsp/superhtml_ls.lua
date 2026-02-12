-- /qompassai/Diver/lsp/superhtml_ls.lua
-- Qompass AI SuperHTML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'superhtml',
        'lsp',
    },
    filetypes = {
        'htm',
        'html',
        'shtml',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
