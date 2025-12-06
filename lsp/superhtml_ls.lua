-- /qompassai/Diver/lsp/superhtml_ls.lua
-- Qompass AI SuperHTML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['superhtml_ls'] = {
  cmd = {
    'superhtml',
    'lsp'
  },
  filetypes = {
    'superhtml',
    'html' },
  root_markers = {
    '.git'
  },
}