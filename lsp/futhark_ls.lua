-- futhark_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'futhark', 'lsp' },
  filetypes = { 'futhark', 'fut' },
  root_markers = { '.git' },
}