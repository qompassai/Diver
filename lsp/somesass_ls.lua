-- /qompassai/Diver/lsp/somesass_ls.lua
-- Qompass AI Some Sass LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g some-sass-language-server
vim.lsp.config['somesass_ls'] = {
  cmd = {
    'some-sass-language-server', '--stdio' },
  filetypes = {
    'scss',
    'sass'
  },
  root_markers = {
    '.git',
    '.package.json',
    '.package.jsonc'
  },
  settings = {
    somesass = {
      suggestAllFromOpenDocument = true,
    },
  },
}