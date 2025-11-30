-- /qompassai/Diver/lsp/mm0ls.lua
-- Qompass AI MetaMath Zero LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://github.com/digama0/mm0/tree/master/mm0-rs)
---@type vim.lsp.Config
return {
  cmd = { "mm0-rs", "server" },
  root_markers = { ".git" },
  filetypes = { "metamath-zero" },
}
