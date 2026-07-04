---@version 5.1, JIT
-- /qompassai/Diver/lsp/debputy_ls.lua
-- Qompass AI Diver Debian Package (Debputy) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@source  https://salsa.debian.org/debian/debputy
return ---@type vim.lsp.Config
{
  cmd = {
    'debputy',
    'lsp',
    'server',
  },
  filetypes = {
    'autopkgtest',
    'debcontrol',
    'debcopyright',
    'debchangelog',
    'make',
    'yaml',
  },
  root_markers = {
    'debian',
  },
}
