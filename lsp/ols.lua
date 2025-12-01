-- /qompassai/Diver/lsp/ols.lua
-- Qompass AI Odin LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["ols"] = {
  cmd = {
    "ols",
  },
  filetypes = {
    "odin",
  },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor",
      "source.organizeImports",
    },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = {
    full = true,
    legend = {
      tokenModifiers = {
        "declaration",
        "definition",
        "readonly",
        "documentation",
      },
      tokenTypes = {
        "namespace",
        "type",
        "class",
        "struct",
        "parameter",
        "variable",
        "property",
        "function",
        "method",
        "keyword",
        "comment",
        "string",
        "number",
        "operator",
      },
    },
    range = true,
  },
  settings = {
    ols = {},
  },
}
