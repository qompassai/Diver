-- /qompassai/Diver/lsp/autotools.lua
-- Qompass AI AutoTools LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['autotoo_ls'] = {
  cmd = {
    'autotools-language-server',
  },
  filetypes = {
    'automake',
    'config',
    'make'
  },
  root_markers = {
    'configure.ac',
    'Makefile',
    'Makefile.am',
    '*.mk'
  },
}