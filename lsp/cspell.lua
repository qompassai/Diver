-- /qompassai/Diver/lsp/cspell_lsp.lua
-- Qompass AI Code Spell LSP Spec (cspell-lsp)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["cspell-lsp"] = {
  cmd = {
    "cspell-lsp",
    "--stdio",
  },
  filetypes = {
    "lua",
    "vim",
    "bash",
    "sh",
    "zsh",
    "python",
    "ruby",
    "go",
    "rust",
    "java",
    "php",
    "javascript",
    "typescript",
    "tsx",
    "jsx",
    "markdown",
    "mdx",
    "json",
    "yaml",
    "toml",
    "gitcommit",
  },
  codeActionProvider = {
    codeActionKinds = { "", "quickfix" },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  init_options = {
    home = vim.fn.stdpath("config"),
    logLevel = "info",
  },
  settings = {
    cspell = {
      configFile = "cspell.json",
      enabled = true,
      language = "en, en-US",
      files = { "**/*" },
      ignoreWords = {
        "Qompass",
        "makefile",
        "hyprland",
        "hyprls",
      },
      ignoreRegExpList = {
        "/0x[0-9A-Fa-f]+/g",
        "/[0-9a-fA-F-]{36}/g",
      },
      dictionaries = {
        "en_us",
        "softwareTerms",
        "filetypes",
        "typescript",
      },
      allowCompoundWords = true,
      maxNumberOfProblems = 100,
      numSuggestions = 8,
      suggestionsTimeout = 500,
      showStatus = true,
      checkLimit = 5000,
    },
  },
}
