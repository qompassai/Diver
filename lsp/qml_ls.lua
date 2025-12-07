-- /qompassai/Diver/lsp/qml_ls.lua
-- Qompass AI QML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['qml_ls'] = {
  cmd = {
    'qml-lsp'
  },
  filetypes = {
    'qml',
    'qmljs'
  },
  settings = {},
}