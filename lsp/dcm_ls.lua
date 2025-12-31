-- dcm_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'dcm', 'start-server', '--client=neovim' },
  filetypes = { 'dart' },
  root_markers = { 'pubspec.yaml' },
}