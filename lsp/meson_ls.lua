-- meson_ls.lua
-- Qompass AI Meson LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/JCWasmx86/mesonlsp
vim.lsp.config['mesonlsp'] = {
  cmd = {
    'mesonlsp',
    '--lsp'
  },
  filetypes = {
    'meson'
  },
  root_markers = {
    'meson.build'
  },
}