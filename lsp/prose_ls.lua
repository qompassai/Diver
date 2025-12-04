-- /qompassai/Diver/lsp/prose_ls.lua
-- Qompass AI ProseMD LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--https://github.com/kitten/prosemd-lsp
vim.lsp.config['prosemd-lsp'] = {
  cmd = {
    'prosemd-lsp',
    '--stdio'
  },
  filetypes = { 'markdown' },
  root_markers = { '.git' },
}