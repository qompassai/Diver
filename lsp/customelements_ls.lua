-- customelements_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['customelements_ls'] = {
  init_options = {
    hostInfo = 'neovim'
  },
  cmd = {
    'custom-elements-languageserver',
    '--stdio'
  },
  root_markers = {
    'tsconfig.json',
    'package.json',
    'jsconfig.json',
    '.git'
  },
}