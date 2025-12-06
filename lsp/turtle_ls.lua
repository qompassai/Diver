-- /qompassai/Diver/lsp/turtle_ls.lua
-- Qompass AI Turtle LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--pnpm add -g turtle-language-server
--Reference: ttps://github.com/stardog-union/stardog-language-servers/tree/master/packages/turtle-language-server
vim.lsp.config['turtle-language-server'] = {
  cmd = {
    'node',
    'turtle-language-server',
    '--stdio'
  },
  filetypes = {
    'turtle',
    'ttl'
  },
  root_markers = {
    '.git'
  },
}