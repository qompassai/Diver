-- /qompassai/Diver/lsp/pb_ls.lua
-- Qompass AI Protobuf (Pb) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://git.sr.ht/~rrc/pbls
--cargo install --git https://git.sr.ht/~rrc/pbls
vim.lsp.config['pb_ls'] = {
  cmd = {
    'pbls'
  },
  filetypes = {
    'proto'
  },
  root_markers = {
    '.pbls.toml',
    '.git'
  },
}