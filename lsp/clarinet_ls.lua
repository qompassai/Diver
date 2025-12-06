-- /qompassai/Diver/lsp/clarinet_ls.lua
-- Qompass AI Clarinet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['clarinet_ls'] = {
  cmd = {
    'clarinet',
    'lsp'
  },
  filetypes = {
    'clar',
    'clarity'
  },
  root_markers = {
    'Clarinet.toml'
  },
}