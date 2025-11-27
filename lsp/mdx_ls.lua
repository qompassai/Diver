-- /qompassai/Diver/lsp/mdx_ls.lua
-- Qompass AI Markdown X (MDX) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References: https://mdxjs.com/
-- pnpm add -g @mdx-js/language-server
vim.lsp.config['mdx-language-server'] = {
  autostart = true,
  cmd = { "mdx-language-server", "--stdio" },
  filetypes = { "mdx" },
 -- root_dir = vim.fn.getcwd,
  root_markers = { "package.json", "package.json5" },
  codeActionProvider = {
    codeActionKinds = { "", "quickfix", "refactor", "source.organizeImports" },
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
        "static",
        "deprecated",
        "documentation",
        "defaultLibrary",
      },
      tokenTypes = {
        "namespace", "type", "class", "enum", "interface", "typeParameter", "parameter",
        "variable", "property", "enumMember", "event", "function", "method", "macro",
        "keyword", "modifier", "comment", "string", "number", "regexp", "operator", "decorator",
      },
    },
    range = true,
  },
  init_options = {
    locale = "en",
    typescript = {
      enabled = true,
    },
  },
  settings = {
    mdx = {
      trace = {
        server = {
          format = "text",
          verbosity = "verbose",
        },
      },
      validate = {
        validateReferences = "info",
      },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = true,
}