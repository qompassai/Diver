-- /qompassai/Diver/lsp/vt_ls.lua
-- Qompass AI Typescript Extension Wrapper LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/yioneko/vtsls
local vue_plugin = {
  name = '@vue/typescript-plugin',
  location = 'node_modules/@vue/typescript-plugin',
  languages = {
    'javascript',
    'typescript',
    'vue'
  },
}
vim.lsp.config['vts_ls'] = {
  cmd = {
    'vtsls',
    '--stdio'
  },
  init_options = {
    hostInfo = 'neovim',
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = {
    'package-lock.json',
    'yarn.lock',
    'pnpm-lock.yaml',
    'bun.lockb',
    'bun.lock'
  },
  settings = {
    vtsls = {
      tsserver = {
        globalPlugins = {
          vue_plugin,
        },
      },
    },
  },
}