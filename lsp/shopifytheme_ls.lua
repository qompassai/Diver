-- shopifytheme_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'shopify',
    'theme',
    'language-server',
  },
  filetypes = { 'liquid' },
  root_markers = {
    '.shopifyignore',
    '.theme-check.yml',
    '.theme-check.yaml',
    'shopify.theme.toml',
  },
  settings = {},
}