-- /qompassai/Diver/lsp/please.lua
-- Qompass AI Please LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/thought-machine/please
--curl -s https://get.please.build | bash
vim.lsp.config['plz'] = {
  cmd = {
    'plz',
    'tool',
    'lps'
  },
  filetypes = {
    'bzl'
  },
  root_markers = {
    '.plzconfig'
  },
}