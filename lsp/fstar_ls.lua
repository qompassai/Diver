-- /qompassai/Diver/lsp/fstar_ls.lua
-- Qompass AI FStar LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'fstar',
    '--lsp',
  },
  filetypes = {
    'fstar',
  },
  root_markers = {
    '.git',
  },
}