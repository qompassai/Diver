-- /qompassai/Diver/lsp/crystalline_ls.lua
-- Qompass AI Crystalline LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'crystalline',
  },
  filetypes = {
    'crystal',
  },
  root_markers = {
    'shard.yml',
    '.git',
  },
}