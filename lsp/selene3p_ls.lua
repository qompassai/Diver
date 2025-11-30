-- /qompassai/Diver/lsp/selene3p_ls.lua
-- Qompass AI Selene 3P LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['selene3p_ls'] = {
  cmd = {
    'selene-3p-language-server',
  },

  filetypes = {
    'lua',
    'luau',
  },

  root_markers = {
    '.selene.toml',
    'selene.toml',
    '.git',
  },

  codeActionProvider = {
    codeActionKinds = {
      '',
      'quickfix',
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

  documentFormattingProvider = false,
  documentHighlightProvider = false,
  documentRangeFormattingProvider = false,
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
