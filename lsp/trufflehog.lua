-- /qompassai/Diver/lsp/trufflehog.lua
-- Qompass AI TruffleHog LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["trufflehog"] = {
  cmd = {
    "trufflehog",
  },
  filetypes = {
    "gitcommit",
    "yaml",
    "json",
    "jsonc",
    "sh",
    "bash",
    "zsh",
    "terraform",
    "dockerfile",
    "*",
  },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    trufflehog = {},
  },
}
