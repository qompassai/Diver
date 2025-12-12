-- /qompassai/Diver/lsp/proto_ls.lua
-- Qompass AI Protobuf LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- cargo install protols
vim.lsp.config['proto_ls'] = {
  cmd = {
    "protols",
  },
  filetypes = {
    "proto",
  },
  root_markers = {
    ".git",
  },
}