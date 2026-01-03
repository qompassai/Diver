-- /qompassai/Diver/lsp/abaplint_ls.lua
-- Qompass AI Diver Abaplint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'abaplint',
    '--lsp',
  },
  filetypes = {
    'abap'
  },
  root_markers = {
    'abaplint.json',
    '.git',
  },
  settings = {},
}