-- yang_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'yang-language-server' },
  filetypes = { 'yang' },
  root_markers = { '.git' },
}