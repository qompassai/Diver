-- regal_ls.lua
-- Qompass AI Regal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/StyraInc/regal
vim.lsp.config['regal'] = {
  cmd = {
    'regal',
    'language-server'
  },
  filetypes = { 'rego' },
  root_markers = {
    '.git',
  },
}