-- /qompassai/Diver/lsp/awk_ls.lua
-- Qompass AI Awk_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

vim.lsp.config["awk_ls"] = {
  cmd = { "awk-language-server" },
  filetypes = { "awk" },
}
