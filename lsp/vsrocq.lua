-- /qompassai/Diver/lsp/vsrocq.lua
-- Qompass AI VSRocq LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { "vsrocqtop" },
  filetypes = { "coq" },
  root_markers = { "_RocqProject", "_CoqProject", ".git" },
}
