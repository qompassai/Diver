-- /qompassai/diver/lsp/platuml_ls.lua
-- Qompass AI PlatUML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'platuml-lsp'
  },
  filetypes = {
    'platuml'
  },
  root_markers = {
    '.git'
  },
  settings = {},
}