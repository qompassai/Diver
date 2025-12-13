-- vespa_ls.lua
-- Qompass AI Vespa LSP
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['vespa_ls'] = {
  cmd = {
    'java',
    '-jar',
    'vespa-language-server.jar',
  },
  filetypes = {
    'sd',
    'profile',
    'yql',
  },
  root_markers = {
    '.git',
  },
}