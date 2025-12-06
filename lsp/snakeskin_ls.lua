-- /qompassai/Diver/lsp/snakeskin_ls.lua
-- Qompass AI SnakeSkin LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------
-- Reference: https://www.npmjs.com/package/@snakeskin/cli
-- pnpm add -g @snakeskin/cli
vim.lsp.config['snakeskin_ls'] = {
  cmd = {
    'snakeskin-cli',
    'lsp',
    '--stdio'
  },
  filetypes = {
    'ss'
  },
  root_markers = {
    'package.json'
  },
}