-- /qompassai/Diver/lsp/brioche_ls.lua
-- Qompass AI Brioche LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'brioche',
    'lsp',
  },
  filetypes = {
    'brioche',
  },
  root_markers = {
    'project.bri',
  },
}