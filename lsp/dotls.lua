-- /qompassai/Diver/lsp/dotls.lua
-- Qompass AI Dot Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['dot-language-server'] = {
  cmd = { 'dot-language-server',
    '--stdio'
  },
  filetypes = {
    'dot'
  },
}