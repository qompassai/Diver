-- /qompassai/Diver/lsp/fish_ls.lua
-- Qompass AI Fish LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/ndonfris/fish-lsp
vim.lsp.config['fish_ls'] = {
  cmd = {
    'fish-lsp',
    'start'
  },
  filetypes = {
    'fish'
  },
  root_markers = {
    'config.fish',
    '.git'
  },
}