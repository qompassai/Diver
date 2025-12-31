-- /qompassai/Diver/lsp/cir_ls.lua
-- Qompass AI LLVM ClangIR LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://llvm.github.io/clangir

return ---@type vim.lsp.Config
{
  cmd = {
    'cir-lsp-server'
  },
  filetypes = {
    'cir'
  },
  root_markers = {
    '.git'
  },
}