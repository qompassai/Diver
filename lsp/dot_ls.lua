-- /qompassai/Diver/lsp/dot_ls.lua
-- Qompass AI Dot Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'dot-language-server',
    '--stdio',
  },
  filetypes = {
    'dot',
  },
  root_markers = {
    '.git'
  },
}