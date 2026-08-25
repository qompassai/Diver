-- /qompassai/Diver/lsp/bq_ls.lua
-- Qompass AI Big Query (BQ) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
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
