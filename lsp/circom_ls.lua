-- /qompassai/Diver/circom_ls.lua
-- Qompass AI Circom LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://github.com/rubydusa/circom-lsp
-- cargo install circom-lsp
vim.lsp.config['circom-lsp'] = {
  cmd = {
    'circom-lsp'
  },
  filetypes = {
    'circom'
  },
  root_markers = {
    '.git'
  },
}