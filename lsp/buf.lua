-- /qompassai/Diver/lsp/buf.lua
-- Qompass AI Buf_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['buf'] = {
  default_config = {
    cmd = {
      "buf",
      "beta",
      "lsp",
      "--timeout=0",
      "--log-format=text"
    },
    filetypes = {
      "proto"
    },
  },
}