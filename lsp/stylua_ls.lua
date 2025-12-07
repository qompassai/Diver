-- /qompassai/Diver/lsp/stylua_ls.lua
-- Qompass AI Stylua LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References: https://docs.rs/crate/stylua/2.3.1
-- cargo install stylua --features luajit
vim.lsp.config['stylua_ls'] = {
  cmd = {
    'stylua',
    ' --lsp'
  },
  filetypes = {
    'lua',
    'luau'
  },
  root_markers = {
    '.editorconfig',
    '.stylua.toml',
    'stylua.toml'
  },
}