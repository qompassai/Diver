-- /qompassai/Diver/lsp/bashls.lua
-- Qompass AI Bashls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['bashls'] = {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash" },
  settings = {
    bashIde = {
      globPattern = "**/*@(.sh|.inc|.bash|.command)",
      maxNumberOfProblems = 100,
      shellcheck = {
        enable = true,
        executablePath = "shellcheck",
        severity = {
          error = "error",
          warning = "warning",
          info = "info",
          style = "info",
        },
      },
      completion = {
        enabled = true,
        includeDirs = {},
      },
      diagnostics = {
        enabled = true,
      },
    },
  },
}