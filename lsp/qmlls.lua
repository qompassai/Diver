-- /qompassai/Diver/lsp/qmlls.lua
-- Qompass AI QML LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['qmlls'] = {
  cmd = { 'qml-lsp' },
  filetypes = { 'qml', 'qmljs' },
  single_file_support = true,
  settings = {},
  flags = {
    debounce_text_changes = 150,
  },
}