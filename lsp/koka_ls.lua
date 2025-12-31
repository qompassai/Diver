-- koka_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'koka', '--language-server', '--lsstdio' },
  filetypes = { 'koka' },
  root_markers = { '.git' },
}