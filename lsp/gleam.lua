-- /qompassai/Diver/lsp/gleam.lua
-- Qompass AI Gleam LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['gleam'] = {
  cmd = {
    'gleam',
    'lsp',
  },
  filetypes = {
    'gleam',
  },
  root_markers = {
    'gleam.toml',
    '.git',
  },
}