-- protols.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- cargo install protols
---@type vim.lsp.Config
return {
  cmd = { 'protols' },
  filetypes = { 'proto' },
  root_markers = { '.git' },
}