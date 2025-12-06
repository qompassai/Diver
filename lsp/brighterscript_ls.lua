-- /qompassai/Diver/lsp/brighterscript_ls.lua
-- Qompass AI BrighterScript LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['brighterscript_ls'] = {
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