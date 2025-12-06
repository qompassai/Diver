-- /qompassai/Diver/lsp/fstar_ls.lua
-- Qompass AI FStar LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://fstar-lang.org/ | https://github.com/FStarLang/FStar
-- opam install fstar
vim.lsp.config['fstar_ls'] = {
  cmd = {
    'fstar',
    '--lsp'
  },
  filetypes = {
    'fstar'
  },
  root_markers = {
    '.git'
  },
}