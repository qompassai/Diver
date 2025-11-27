-- /qompassai/Diver/lsp/statix.lua
-- Qompass AI Statix LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'statix', 'check', '--stdin' },
  filetypes = { 'nix' },
  root_markers = { 'flake.nix', '.git' },
}