-- /qompassai/Diver/lsp/jsonls.lua
-- Qompass AI Qompass AI Javascript Object Notation (JSON) LD LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
---------------------------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'jsonld-lsp',
    '--stdio',
  },
  filetypes = {
    'jsonld',
  },
  init_options = {
  },
  root_markers = { '.git' },
  settings = {},
}