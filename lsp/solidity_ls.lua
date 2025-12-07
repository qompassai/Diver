-- /qompassai/Diver/lsp/solidity_ls.lua
-- Qompass AI Solidity LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- #Reference: https://github.com/qiuxiang/solidity-ls
-- pnpm add -g solidity-ls
vim.lsp.config['solidity_ls'] = {
  cmd = {
    'solidity-ls',
    '--stdio'
  },
  filetypes = {
    'solidity'
  },
  root_markers = {
    '.git',
    'package.json'
  },
  settings = {
    solidity = {
      includePath = '',
      remapping = {}
    }
  },
}