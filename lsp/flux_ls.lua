-- /qompassai/Diver/lsp/flux_ls.lua
-- Qompass AI Flux LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/influxdata/flux-lsp
-- cargo install --git https://github.com/influxdata/flux-lsp
vim.lsp.config['flux_ls'] = {
  cmd = {
    'flux-lsp'
  },
  filetypes = {
    'flux'
  },
  root_markers = {
    '.git'
  },
}