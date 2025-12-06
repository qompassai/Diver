-- /qompassai/Diver/lsp/beancount.lua
-- Qompass AI Beancount LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['beancount_ls'] = {
  cmd = {
    'beancount-language-server',
  },
  filetypes = {
    "beancount",
  },
  root_markers = {
    'main.bean',
    'beancount.conf',
    '.git',
  },
}