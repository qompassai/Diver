-- /qompassai/diver/lsp/pest_ls.lua
-- Qompass AI Pest LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'pest-language-server',
    },
    filetypes = {
        'pest',
    },
    root_markers = {
        '.git',
    },
}
