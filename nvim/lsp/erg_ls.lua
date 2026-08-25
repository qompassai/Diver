-- erg_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'erg', '--language-server' },
    filetypes = { 'erg' },
    root_markers = { 'package.er', '.git' },
}
