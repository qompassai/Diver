-- /qompassai/Diver/lsp/superhtml.lua
-- Qompass AI Superhtml LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config["superhtml"] = {
  cmd = { "superhtml", "lsp" },
  filetypes = { "superhtml", "html" },
  root_markers = { ".git" },
}
