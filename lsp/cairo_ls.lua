-- /qompassai/Diver/lsp/cairo_ls.lua
-- Qompass AI Cairo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'scarb',
    'cairo-language-server',
    '/C',
    '--node-ipc',
  },
  init_options = {
    hostInfo = 'neovim',
  },
  filetypes = {
    'cairo',
  },
  root_markers = {
    'Scarb.toml',
    'cairo_project.toml',
    '.git',
  },
}