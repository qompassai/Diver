-- /qompassai/Diver/lsp/cssls.lua
-- Qompass AI Css_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config["cssls"] = {
  cmd = { "vscode-css-language-server", "--stdio" },
  filetypes = { "css", "scss", "less" },
  init_options = {
    provideFormatter = true,
  },
  settings = {
    cssVariables = {
      lookupFiles = {
        "**/*.css",
        "**/*.scss",
        "**/*.sass",
        "**/*.less",
      },
    },
  },
}
