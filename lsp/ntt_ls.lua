-- /qompassai/Diver/lsp/ntt_ls.lua
-- Qompass AI Nokia TTCN-3 Toolset LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/nokia/ntt
-- go install github.com/nokia/ntt@latest
---@type vim.lsp.Config
return {
  cmd = {
    'ntt',
    'langserver',
  },
  filetypes = {
    'ttcn',
  },
  root_markers = {
    '.git',
  },
}