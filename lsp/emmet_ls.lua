-- /qompassai/Diver/lsp/emmet_ls.lua
-- Qompass AI Emmet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: --- https://github.com/olrtg/emmet-language-server
-- pnpm add -g g @olrtg/emmet-language-server
vim.lsp.config['emmet_ls'] = {
  cmd = {
    'emmet-language-server',
    '--stdio'
  },
  filetypes = {
    'astro',
    'css',
    'eruby',
    'html',
    'htmlangular',
    'htmldjango',
    'javascriptreact',
    'less',
    'pug',
    'sass',
    'scss',
    'svelte',
    'templ',
    'typescriptreact',
    'vue',
  },
  root_markers = {
    '.git'
  },
}