-- /qompassai/Diver/lsp/coq_lsp.lua
-- Qompass AI Coq LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

local coq_lsp_bin = "coq-lsp"

vim.lsp.config["coq_lsp"] = {
  cmd = { coq_lsp_bin },
  filetypes = { "coq" },
  root_markers = { "_CoqProject", ".coq-lsp", ".git" },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor",
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
    ["coq-lsp"] = {},
  },
}
