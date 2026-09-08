-- /qompassai/Diver/lsp/prose_ls.lua
-- Qompass AI ProseMD LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'prosemd-lsp',
        '--stdio',
    },
    filetypes = {
        'markdown.readme',
    },
    root_markers = {
        '.git',
    },
    settings = {
        prosemd = {
            validate = true,
        },
    },
}
