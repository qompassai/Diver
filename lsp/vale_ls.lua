-- /qompassai/Diver/lsp/vale_ls.lua
-- Qompass AI Vale LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
    cmd = {
        'vale-ls',
    },
    filetypes = {
        'asciidoc',
        'markdown',
        'text',
        'tex',
        'rst',
        'html',
        'xml',
    },
    root_markers = {
        '.vale.ini',
    },
    settings = {},
}