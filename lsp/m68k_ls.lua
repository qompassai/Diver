-- /qompassai/Diver/lsp/m68k_ls.lua
-- Qompass AI Motorola 68000 Assembly LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['m68k_ls'] = {
  cmd = {
    'm68k-lsp-server',
    '--stdio'
  },
  filetypes = {
    'asm68k'
  },
  root_markers = {
    'Makefile',
    '.git'
  },
}