-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
require("lspconfig").csharp_ls.setup({
  cmd = { "csharp-ls" },
  filetypes = { "cs" },
  root_dir = require("lspconfig").util.root_pattern("*.sln", "*.csproj"),
})
