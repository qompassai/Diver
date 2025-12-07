-- /qompassai/Diver/lsp/please_ls.lua
-- Qompass AI Please LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/thought-machine/please
--curl -s https://get.please.build | bash
vim.lsp.config['please_ls'] = {
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