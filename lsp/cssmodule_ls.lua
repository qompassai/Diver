-- cssmodule_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['cssmodule_ls'] = {
  cmd = {
    'cssmodules-language-server'
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'typescript',
    'typescriptreact'
  },
  root_markers = { 'package.json' },
}