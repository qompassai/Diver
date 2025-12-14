-- /qompassai/Diver/lsp/bq_ls.lua
-- Qompass AI Big Query (BQ) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['bq_ls'] = {
    cmd = {
        'bqls',
    },
    filetypes = {
        'sql',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
