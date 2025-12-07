-- /qompassai/Diver/lsp/ziggy.lua
-- Qompass AI Ziggy LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['ziggy_ls'] = {
  cmd = {
    'ziggy',
    'lsp'
  },
  filetypes = {
    'ziggy'
  },
  root_markers = {
    '.git'
  },
}