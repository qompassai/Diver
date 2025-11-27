-- /qompassai/Diver/lsp/air.lua
-- Qompass AI Air LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['air'] = {
  default_config = {
    cmd = { 'air' },
    filetypes = {
      'r'
    },
    single_file_support = true,
  },
}