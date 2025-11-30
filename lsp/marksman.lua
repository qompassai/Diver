-- /qompassai/Diver/lsp/marksman.lua
-- Qompass AI Marksman LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config["marksman"] = {
  cmd = { "marksman", "server" },
  filetypes = { "markdown", "markdown.mdx" },
  root_markers = {
    ".marksman.toml",
    ".git",
    ".hg",
    ".svn",
  },
  single_file_support = true,
}
