-- /qompassai/Diver/lsp/stylua.lua
-- Qompass AI Stylua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['stylua'] = {
  cmd = {
    "stylua",
    "--lsp",
  },
  filetypes = {
    "lua",
  },
  codeActionProvider = false,
  colorProvider = false,
  root_markers = {
    ".stylua.toml",
    "stylua.toml",
    ".editorconfig",
  },
  semanticTokensProvider = nil,
  settings = {
    stylua = {},
  },
}
