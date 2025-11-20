-- /qompassai/Diver/lsp/efm.lua
-- Qompass AI EFM LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
vim.lsp.config['efm-langserver'] = {
  default_config = {
    cmd = { 'efm-langserver' },
    filetypes = {
      'cpp'
    },
    root_markers = { '.git' },
    single_file_support = true,
  },
}