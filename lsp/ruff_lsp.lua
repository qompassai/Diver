-- /qompassai/Diver/lsp/ruff_lsp.lua
-- Qompass AI Ruff LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

vim.lsp.config["ruff_lsp"] = {
  cmd = { "ruff-lsp" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "ruff.toml", ".git" },
  settings = {},
}
