-- /qompassai/Diver/lsp/dprint.lua
-- Qompass AI DPrint LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['dprint_ls'] = {
  cmd = {
    'dprint',
    'lsp'
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
    "markdown",
    "python",
    "toml",
    "rust",
    "roslyn",
    "graphql",
  },
  settings = {},
}