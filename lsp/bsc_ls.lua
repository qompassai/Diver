-- /qompassai/Diver/lsp/bsc_ls.lua
-- Qompass AI BrighterScript LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'bsc',
    '--lsp',
    '--stdio',
  },
  filetypes = {
    'brs',
  },
  root_markers = {
    'makefile',
    'Makefile',
    '.git',
  },
}