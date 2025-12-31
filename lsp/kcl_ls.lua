-- kcl_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'kcl-language-server' },
  filetypes = { 'kcl' },
  root_markers = { '.git' },
}