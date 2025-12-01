-- /qompassai/Diver/lsp/rune_ls.lua
-- Qompass AI Rune LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://rune-rs.github.io/api/rune/
-- cargo install rune-languageserver
vim.lsp.config['rune-languageserver'] = {
  cmd = {
    'rune-languageserver'
  },
  filetypes = {
    'rune',
  },
  root_markers = {
    'Cargo.toml',
    'rune.toml',
    '.git',
  },
}