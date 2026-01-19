-- /qompassai/diver/lsp/nobl9_ls.lua
-- Qompass AI Nobl9 LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return { ---@type vim.lsp.Config
    {
        cmd = {
            'nobl9-language-server',
        },
        filetypes = {
            'yaml',
        },
        root_markers = {
            '.git',
        },
        settings = {},
    },
}
