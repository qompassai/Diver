-- /qompassai/Diver/lsp/agda_ls
-- Qompass AI Diver Agda LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'als',
    },
    filetypes = {
        'agda',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        '*.agda_lib',
        '.git',
    },
}