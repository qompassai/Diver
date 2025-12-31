-- hhvm_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'hh_client', 'lsp' },
  filetypes = { 'php', 'hack' },
  root_markers = { '.hhconfig' },
}