-- hie_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
    cmd = { 'hie-wrapper', '--lsp' },
    filetypes = { 'haskell' },
    root_markers = { 'stack.yaml', 'package.yaml', '.git' },
}
