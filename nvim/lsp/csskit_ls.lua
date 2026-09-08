#!/usr/bin/env lua5.1, JIT

-- csskit_ls.lua
-- Qompass AI Diver CSSKit LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@source  https://github.com/csskit/csskit
---pnpm add -g csskit

---@type vim.lsp.Config
return {
  cmd = {
    'csskit',
    'lsp',
  },
  filetypes = {
    'css',
  },
  root_markers = {
    'package.json',
    '.git',
  },
}
