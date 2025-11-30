-- /qompassai/Diver/lsp/ocamllsp.lua
-- Qompass AI OCaml LSP Spec (ocamllsp / ocaml-lsp-server)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------

vim.lsp.config["ocamllsp"] = {
  cmd = {
    "ocamllsp",
  },
  filetypes = {
    "ocaml",
    "ocamlinterface",
    "ocamllex",
    "reason",
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
      tokenModifiers = { "declaration", "definition", "readonly", "documentation" },
      tokenTypes = {
        "namespace",
        "type",
        "class",
        "module",
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
    ["ocaml-lsp"] = {
      codelens = {
        enable = true,
      },
      inlayHints = {
        enable = true,
      },
      diagnostics = {
        enable = true,
      },
      formatting = { enable = true },
      server = {},
    },
  },
}
