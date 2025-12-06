-- /qompassai/Diver/lsp/laravel_ls.lua
-- Qompass AI Laravel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['laravel_ls'] = {
  cmd = {
    'laravel-ls',
  },
  filetypes = {
    'php',
    'blade',
  },
  root_markers = {
    'artisan',
    'composer.json',
    '.git',
  },
  settings = {
    ['laravel-ls'] = {},
  },
}