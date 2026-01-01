-- vale_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'vale-ls' },
    filetypes = { 'asciidoc', 'markdown', 'text', 'tex', 'rst', 'html', 'xml' },
    root_markers = { '.vale.ini' },
}
