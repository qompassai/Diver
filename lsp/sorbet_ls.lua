-- /qompassai/Diver/lsp/sorbet_ls.lua
-- Qompass AI Sorbet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['sorbet'] = {
  cmd = {
    'srb',
    'tc',
    '--lsp'
  },
  filetypes = {
    'ruby'
  },
  root_markers = {
    'Gemfile',
    '.git'
  },
}