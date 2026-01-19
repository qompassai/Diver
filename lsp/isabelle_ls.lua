-- /qompassai/Diver/lsp/isabelle_ls.lua
-- Qompass AI Isabelle LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'isabelle-lsp',
    },
    filetypes = {
        'isabelle',
        'isabelle_thy',
    },
    root_markers = {},
    settings = {
        isabelle = {
            isabelle_path = 'isabelle',
            log = nil,
            vsplit = false,
            sh_path = 'sh',
            unicode_symbols_output = false,
            unicode_symbols_edits = false,
        },
    },
}