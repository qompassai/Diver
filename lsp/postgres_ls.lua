-- /qompassai/Diver/lsp/postgres_ls.lua
-- Qompass AI Postgres LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References:  https://pgtools.dev
vim.lsp.config['postgres_ls'] = {
  cmd = {
    'postgres-language-server',
    'lsp-proxy'
  },
  filetypes = {
    'sql',
    'psql'
  },
  root_dir = vim.fn.getcwd,
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor",
      "refactor.extract",
    },
    resolveProvider = true,
  },
  completionProvider = {
    triggerCharacters = { ".", '"', "'", " ", "(", "," },
  },
  hoverProvider = true,
  definitionProvider = true,
  referencesProvider = true,
  documentSymbolProvider = true,
  documentHighlightProvider = true,
  renameProvider = true,
  documentFormattingProvider = true,
  documentRangeFormattingProvider = true,
  settings = {},
}