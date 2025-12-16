-- /qompassai/Diver/lsp/clarinet_ls.lua
-- Qompass AI Clarinet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'clarinet',
    'lsp',
  },
  filetypes = {
    'clar',
    'clarity',
  },
  root_markers = {
    'Clarinet.toml',
  },
}