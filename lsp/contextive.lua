-- /qompassia/Diver/lsp/contextive.lua
-- Qompass AI Contextive LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/dev-cycles/contextive
-- curl -L -o Contextive.LanguageServer.zip "https://github.com/dev-cycles/contextive/releases/download/v1.17.8/Contextive.LanguageServer-linux-x64-1.17.8.zip"
vim.lsp.config['contextive'] = {
  cmd = {
    'Contextive.LanguageServer'
  },
  root_markers = {
    '.contextive',
    '.git',
  },
}