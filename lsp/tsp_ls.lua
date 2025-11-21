-- /qompassai/Diver/lsp/tsp_ls.lua
-- Qompass AI TypeSpec (TS) LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
-- pnpm add -g @typespec/compiler
vim.lsp.config['tsp-server'] = {
  cmd = { "tsp-server", "--stdio" },
  filetypes = { "typespec" },
  root_markers = { "tspconfig.yaml", ".git" },
}