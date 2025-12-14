-- /qompassai/Diver/lsp/tsgo.lua
-- Qompass AI Typescript-Go LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- pnpm add -g  @typescript/native-preview@latest
vim.lsp.config['tsgo_ls'] = {
  cmd = {
    'tsgo',
    '--lsp',
    '--stdio',
  },
  filetypes = {
    'javascript',
    'javascript.jsx',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = {
    'bun.lockb',
    'bun.lock',
    '.git',
    'package.json',
    'package-lock.json',
    'pnpm-lock.yaml',
    'yarn.lock',
  },
}