-- /qompassai/Diver/lsp/standardrb.lua
-- Qompass AI Standardrb LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference:  https://github.com/testdouble/standard
--gem install standard
vim.lsp.config['standardrb_ls'] = {
  cmd = {
    'standardrb',
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