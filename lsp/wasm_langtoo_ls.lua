-- /qompassai/Diver/lsp/wasmlangtoo_ls.lua
-- Qompass AI WASM Language Tools LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['wasmlangtoo_ls'] = {
  cmd = {
    "wat_server"
  },
  filetypes = {
    "wat"
  },
}