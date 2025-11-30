-- /qompassai/Diver/lsp/jq_ls.lua
-- Qompass AI jq LSP Spec (jq-lsp)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["jq_ls"] = {
  cmd = { "jq-lsp" },
  filetypes = { "jq" },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor"
    },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    jq = {},
  },
}