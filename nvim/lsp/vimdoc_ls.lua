#!/usr/bin/env lua5.1, JIT

-- /qompassai/diver/lsp/vimdoc_ls.lua
-- Qompass AI Diver Vimdoc LSP Spec
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
---@source https://github.com/barrettruth/vimdoc-language-server
---@type vim.lsp.Config
return {
  cmd = {
    'vimdoc-language-server',
  },
  filetypes = {
    'help',
  },
  root_markers = {
    'doc',
    '.git',
  },
  workspace_required = false,
}
