-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'csharp-ls'
  },
  filetypes = {
    'cs'
  },
  init_options = {
    AutomaticWorkspaceInit = true,
  },
  root_markers = {
    '.sln',
    '.csproj'
  },
}