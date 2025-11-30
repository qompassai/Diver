-- /qompassai/Diver/lsp/systemd_ls.lua
-- Qompass AI Systemd Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config["systemd_ls"] = {
  cmd = { "systemd-language-server" },
  filetypes = { "systemd" },
  root_markers = { ".git" },
}
