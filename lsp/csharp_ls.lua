-- /qompassai/Diver/lsp/csharp_ls.lua
-- Qompass AI Diver Csharp LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
-- Reference: https://github.com/razzmatazz/csharp-language-server
-- dotnet tool install --global csharp-ls
vim.lsp.config['csharp_ls'] = {
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
    '.csproj',
  },
}