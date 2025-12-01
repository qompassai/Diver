-- /qompassai/Diver/lsp/bq_ls.lua
-- Qompass AI Big Query (BQ) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/kitagry/bqls/
-- go install github.com/kitagry/bqls@latest
vim.lsp.config['bqls'] = {
  cmd = {
    'bqls'
  },
  filetypes = {
    'sql'
  },
  root_markers = {
    '.git'
  },
  settings = {},
}