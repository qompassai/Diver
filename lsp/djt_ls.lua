-- /qompassai/Diver/lsp/djt_ls.lua
-- Qompass AI Django Template LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'djlsp'
  },
  filetypes = { 'html', 'htmldjango' },
  root_markers = { '.git' },
  settings = {},
}