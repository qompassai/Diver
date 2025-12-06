-- /qompassai/Diver/lsp/veryl_ls.lua
-- Qompass AI Veryl LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['veryl_ls'] = {
  cmd = {
    'veryl-ls'
  },
  filetypes = {
    'veryl'
  },
  root_markers = {
    '.git'
  },
}