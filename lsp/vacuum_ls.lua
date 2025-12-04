-- /qompassai/Diver/lsp/vacuum_ls.lua
-- Qompass AI Vacuum LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/daveshanley/vacuum
vim.filetype.add {
  pattern = {
    ['openapi.*%.ya?ml'] = 'yaml.openapi',
    ['openapi.*%.json'] = 'json.openapi',
  },
}
vim.lsp.config['vacuum'] = {
  cmd = {
    'vacuum',
    'language-server'
  },
  filetypes = {
    'yaml.openapi',
    'json.openapi'
  },
  root_markers = { '.git' },
}