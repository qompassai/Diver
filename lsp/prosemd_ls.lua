-- /qompassai/Diver/lsp/prose_ls.lua
-- Qompass AI ProseMD LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/kitten/prosemd-lsp
--cargo install prosemd-lsp
vim.lsp.config['prosemd_ls'] = {
  cmd = {
    'prosemd-lsp',
    '--stdio'
  },
  filetypes = {
    'markdown'
  },
  root_markers = {
    '.git'
  },
  settings = {
    prosemd = {
      validate = true,
    },
  },
}