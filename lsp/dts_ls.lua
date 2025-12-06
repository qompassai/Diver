-- /qompassai/Diver/lsp/dts_ls.lua
-- Qompass AI Device Tree Source (DTS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/igor-prusov/dts-lsp
-- cargo install dts-lsp
vim.lsp.config['dts_ls'] = {
  cmd = {
    'dts-lsp'
  },
  filetypes = {
    'dts',
    'dtsi',
    'overlay'
  },
  root_markers = {
    '.git'
  },
  settings = {
    ...
  },
}