-- /qompassai/Diver/lsp/bicep_ls.lua
-- Qompass AI Bicep LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.cmd([[ autocmd BufNewFile,BufRead *.bicep set filetype=bicep ]])
---@type vim.lsp.Config
return {
  cmd = {
    'dotnet',
    'bicep-langserver',
  },
  filetypes = {
    'bicep',
    'bicep-params',
  },
  init_options = {},
  root_markers = {
    '.git',
  },
}