-- /qompassai/Diver/lsp/bsc_ls.lua
-- Qompass AI BrighterScript (Bsc) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference:  https://github.com/RokuCommunity/brighterscript
--pnpm add -g brighterscript
vim.lsp.config['bsc_ls'] = {
  cmd = {
    'bsc',
    '--lsp',
    '--stdio'
  },
  filetypes = {
    'brs'
  },
  root_markers = {
    'makefile',
    'Makefile',
    '.git'
  },
}