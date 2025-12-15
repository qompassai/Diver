-- /qompassai/Diver/lsp/laravel_ls.lua
-- Qompass AI Laravel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'laravel-ls',
  },
  filetypes = {
    'php',
    'blade',
  },
  root_markers = {
    'artisan',
  },
  settings = {
    ['laravel-ls'] = {},
  },
}