-- /qompassai/Diver/lsp/html.lua
-- Qompass AI HTML LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pnpm add -g vscode-langservers-extracted
vim.lsp.config['html'] = {
  cmd = { 'vscode-html-language-server', '--stdio' },
  filetypes = { 'html', 'templ' },
  root_markers = { 'package.json', 'package.json5', '.git' },
  single_file_support = true,
  settings = {},
  init_options = {
    provideFormatter = true,
    embeddedLanguages = {
      css = true,
      javascript = true
    },
    configurationSection = { 'html', 'css', 'javascript' },
  },
}