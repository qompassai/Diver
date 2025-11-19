-- /qompassai/Diver/lsp/mdx_analyzer.lua
-- Qompass AI MDX Analyzer LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['mdx_analyzer'] = {
  autostart = true,
  cmd = { 'mdx-language-server', '--stdio' },
  filetypes = { 'mdx' },
  root_dir = vim.fn.getcwd,
  root_markers = { 'package.json', 'package.json5' },
  single_file_support = true,
  init_options = {
    typescript = {
      tsdk = vim.fn.stdpath("data") .. '/mason/packages/typescript-language-server/node_modules/typescript/lib',
    },
  },
  settings = {
    mdx = {
      lint = {
        enabled = true,
        rules = {
          ["no-dead-urls"] = "error",
          ["no-duplicate-headings"] = "warn",
          ["first-heading-level"] = { 2, "error" },
        },
      },
      format = {
        enabled = true,
        prettier = {
          configPath = ".prettierrc",
        },
      },
      diagnostics = {
        enable = true,
        severity = {
          error = "Error",
          warning = "Warning",
          info = "Information",
          hint = "Hint",
        },
      },
    },
  },
}