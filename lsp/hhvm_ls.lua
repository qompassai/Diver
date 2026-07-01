-- /qompassai/diver/lsp/hhvm_ls.lua
-- Qompass AI Hack LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source --- https://docs.hhvm.com/hhvm/getting-started/getting-started

---@type vim.lsp.Config
return {
  cmd = {
    'hh_client',
    'lsp',
  },
  filetypes = {
    'php',
    'hack',
  },
  root_markers = {
    '.hhconfig',
  },
}
