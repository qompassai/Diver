-- /qompassai/Diver/lsp/salt_ls.lua
-- Qompass AI Salt LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'salt_lsp_server',
    },
    filetypes = {
        'sls',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}
