-- /qompassai/Diver/lsp/smarty_ls.lua
-- Qompass AI Smarty LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--pnpm add -g  vscode-smarty-langserver-extracted
vim.lsp.config['smarty_ls'] = {
  cmd = {
    'smarty-language-server',
    '--stdio'
  },
  filetypes = { 'smarty' },
  room_markers = {
    'composer.json',
    '.git'
  },
  settings = {
    smarty = {
      pluginDirs = {},
    },
    css = {
      validate = true,
    },
  },
  init_options = {
    storageDir = vim.NIL,
  },
}