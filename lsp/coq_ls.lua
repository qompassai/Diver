-- /qompassai/Diver/lsp/coq_lsp.lua
-- Qompass AI Coq LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config['coq_ls'] = {
  cmd = {
    'coq-lsp'
  },
  filetypes = {
    "coq"
  },
  root_markers = {
    "_CoqProject",
    ".coq-lsp",
    ".git"
  },
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
    ['coq-lsp'] = {},
  },
}