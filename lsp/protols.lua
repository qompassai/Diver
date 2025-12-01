-- /qompassai/Diver/lsp/protols.lua
-- Qompass AI Protobuf LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- cargo install protols
vim.lsp.config["protols"] = {
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
