-- /qompassai/Diver/lsp/cairo_ls.lua
-- Qompass AI Cairo LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- cargo install --git https://github.com/software-mansion/scarb scarb
---@type vim.lsp.Config
return {
  init_options = { hostInfo = 'neovim' },
  cmd = { 'scarb', 'cairo-language-server', '/C', '--node-ipc' },
  filetypes = { 'cairo' },
  root_markers = { 'Scarb.toml', 'cairo_project.toml', '.git' },
}