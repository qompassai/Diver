-- /qompassai/Diver/lsp/herb_ls.lua
-- Qompass AI Herb LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['herb_ls'] = {
  cmd = {
    'herb-language-server',
    '--stdio',
  },
  filetypes = {
    'html',
    'eruby',
  },
  init_options = {
    linter = {
      enabled = true
    },
  },
  root_markers = {
    'Gemfile',
    '.git',
  },
}