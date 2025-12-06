-- stimulus_ls.lua
-- Qompass AI Stimulus LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['stimulus_ls'] = {
  cmd = {
    'stimulus-language-server',
    '--stdio'
  },
  filetypes = {
    'html',
    'ruby',
    'eruby',
    'blade',
    'php'
  },
  root_markers = {
    'Gemfile',
    '.git'
  },
}