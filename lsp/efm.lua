-- /qompassai/Diver/lsp/efm.lua
-- Qompass AI EFM LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config["efm-langserver"] = {
  default_config = {
    cmd = {
      "efm-langserver",
    },
    filetypes = {
      "c",
      "cpp",
      "go",
      "json",
      "lua",
      "markdown",
      "python",
      "sh",
      "yaml",
    },
    init_options = {
      documentFormatting = true,
      hover = true,
      lintDebounce = 100,
      lintOnChange = true,
      lintOnSave = true,
      completion = true,
    },
    root_markers = {
      ".git",
      ".hg",
      ".svn",
    },
  },
  codeActionProvider = {
    codeActionKinds = {
      "",
      "quickfix",
      "refactor",
      "refactor.extract",
      "refactor.rewrite",
      "source",
      "source.fixAll",
      "source.organizeImports",
    },
    resolveProvider = false,
  },
  colorProvider = false,
  completionProvider = {
    resolveProvider = false,
    triggerCharacters = {
      ".",
      ":",
      ">",
      '"',
      "'",
      "/",
      "-",
      "#",
    },
  },
  definitionProvider = false,
  declarationProvider = false,
  documentFormattingProvider = true,
  documentHighlightProvider = false,
  documentRangeFormattingProvider = true,
  documentSymbolProvider = false,
  hoverProvider = true,
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
    triggerCharacters = {
      "(",
      ",",
    },
  },
  workspaceSymbolProvider = false,
}
