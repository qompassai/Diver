-- /qompassai/Diver/lsp/wc_ls.lua
-- Qompass AI Web Components LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  init_options = {
    hostInfo = 'neovim'
  },
  cmd = {
    'wc-language-server',
    '--stdio'
  },
  filetypes = {
    'astro',
    'css',
    'html',
    'javascriptreact',
    'typescriptreact',
    'svelte',
    'vue',
    'markdown',
    'mdx',
    'javascript',
    'typescript',

    'scss',
    'less',
  },
  root_markers = {
    'wc.config.js',
    'wc.config.ts',
    'wc.config.mjs',
    'wc.config.cjs',
    'custom-elements.json',
    'package.json',
    '.git',
  },
  tsdk = vim.fn.getcwd() .. '/node_modules/typescript/lib',
}