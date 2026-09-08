-- /qompassai/Diver/lsp/atlas_ls.lua
-- Qompass AI Diver Atlas LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'atlas',
    'tool',
    'lsp',
    '--stdio',
  },
  filetypes = {
    'atlas-*',
  },
  root_markers = {
    'atlas.hcl',
  },
}
