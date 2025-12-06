-- /qompassai/Diver/lsp/solc_ls.lua
-- Qompass AI Solc LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['solc'] = {
  cmd = {
    'solc',
    '--lsp'
  },
  filetypes = {
    'solidity'
  },
  root_markers = {
    'hardhat.config.*',
    '.git'
  },
}