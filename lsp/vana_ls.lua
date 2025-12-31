-- vana_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'v-analyzer' },
  filetypes = { 'v', 'vsh', 'vv' },
  root_markers = { 'v.mod', '.git' },
}