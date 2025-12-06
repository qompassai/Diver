-- /qompassai/Diver/lsp/autotools.lua
-- Qompass AI AutoTools LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['autotools_ls'] = {
  cmd = {
    'autotools-language-server'
  },
  filetypes = {
    'config',
    'automake',
    'make'
  },
  root_markers = {
    'configure.ac',
    "Makefile",
    "Makefile.am",
    "*.mk"
  },
}