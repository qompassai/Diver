-- /qompassai/Diver/lsp/pas_ls.lua
-- Qompass AI Pascal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = {
        'pasls',
    },
    filetypes = {
        'pascal',
    },
    root_markers = {
        '*.lpi',
        '*.lpk',
        '.git',
    },
}
