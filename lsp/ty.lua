-- /qompassai/Dive/lsp/ty.lua
-- Qompass AI TY LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-------------------------------------------
vim.lsp.config["ty"] = {
  cmd = { "ty", "server" },
  filetypes = { "python" },
  root_markers = { "ty.toml", "pyproject.toml", ".git" },
}
