-- /qompassai/Diver/lsp/atopile_ls.lua
-- Qompass AI Atopile LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'ato',
    'lsp',
    'start'
  },
  filetypes = {
    'ato'
  },
  root_markers = {
    'ato.yaml',
    '.ato',
    '.git'
  },
}