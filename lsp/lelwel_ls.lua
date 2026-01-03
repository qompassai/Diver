-- /qompassai/diver/lsp/lelwel_ls.lua
-- Qompass AI LelWel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'lelwel-ls'
  },
  filetypes = {
    'llw'
  },
  root_markers = {
    '.git'
  },
}