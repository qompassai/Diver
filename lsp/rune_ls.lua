-- /qompassai/Diver/lsp/rune_ls.lua
-- Qompass AI Rune LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- cargo install rune-languageserver
---@type vim.lsp.Config
return {
  cmd = { "rune-languageserver" },
  filetypes = { "rune" },
  root_markers = { ".git" },
}
