-- /qompassai/Diver/lsp/nixd_ls.lua
-- Qompass AI Nixd LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['nixd_ls'] = {
  cmd = {
    'nixd',
    '--log=info',
    '--inlay-hints=true',
    '--semantic-tokens=true',
    '--pretty'
  },
  filetypes = {
    'nix',
  },
  root_markers = {
    'flake.nix',
    'default.nix',
    '.git',
  },
}