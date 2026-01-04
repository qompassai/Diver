-- /qompassai/Diver/lsp/sysl_ls.lua
-- Qompass AI Sysl LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'sysl',
    'lsp'
  },
  filetypes = {
    'sysl'
  },
  root_markers = {
    '.git',
    'sysl.yaml',
    'sysl.yml',

  },
  settings = {
  },
}