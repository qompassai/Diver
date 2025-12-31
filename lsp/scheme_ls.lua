-- scheme_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'scheme-langserver', '~/.scheme-langserver.log', 'enable', 'disable' },
  filetypes = { 'scheme' },
  root_markers = {
    'Akku.manifest',
    '.git',
  },
}