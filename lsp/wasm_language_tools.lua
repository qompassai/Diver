-- /qompassai/Diver/lsp/wasm_language_tools.lua
-- Qompass AI WASM Language Tools LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config["wasm_language_tools"] = {
  cmd = { "wat_server" },
  filetypes = { "wat" },
}
