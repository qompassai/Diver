-- /qompassai/Diver/lsp/gleam_ls.lua
-- Qompass AI Gleam LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['gleam_ls'] = {
  cmd = {
    'gleam',
    'lsp',
  },
  filetypes = {
    'gleam',
  },
  root_markers = {
    "gleam.toml",
    ".git",
  },
}