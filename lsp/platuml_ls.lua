-- /qompassai/diver/lsp/plantuml_ls.lua
-- Qompass AI Diver PlantUML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'plantuml-lsp',
    },
    filetypes = {
        'platuml',
    },
    root_markers = {
        '.git',
    },
    settings = {},
}