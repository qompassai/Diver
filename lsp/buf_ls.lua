-- /qompassai/Diver/lsp/bufls.lua
-- Qompass AI Bufls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['bufls'] = {
  default_config = {
    cmd = {
      'bufls',
      'serve'
    },
    filetypes = {
      'proto'
    },
  },
}