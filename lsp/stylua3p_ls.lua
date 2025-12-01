-- /qompassai/Diver/lsp/stylua3p_ls.lua
-- Qompass AI Stylua 3P LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config["stylua3p_ls"] = {
  cmd = {
    "stylua-3p-language-server",
  },
  filetypes = {
    "lua",
    "luau",
  },
  root_markers = {
    ".stylua.toml",
    "stylua.toml",
    ".git",
  },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "source",
      "source.fixAll",
    },
    resolveProvider = false,
  },
  colorProvider = false,
  completionProvider = {
    resolveProvider = false,
    triggerCharacters = {},
  },
  definitionProvider = false,
  declarationProvider = false,
  documentFormattingProvider = true,
  documentHighlightProvider = false,
  documentRangeFormattingProvider = true,
  documentSymbolProvider = false,
  hoverProvider = false,
  implementationProvider = false,
  referencesProvider = false,
  renameProvider = false,
  semanticTokensProvider = {
    full = false,
    legend = {
      tokenModifiers = {},
      tokenTypes = {},
    },
    range = false,
  },
  signatureHelpProvider = {
    triggerCharacters = {},
  },
  workspaceSymbolProvider = false,
}
