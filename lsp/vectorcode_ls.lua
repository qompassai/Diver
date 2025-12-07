-- /qompassai/Diver/lsp/vectorcode_ls.lua
-- Qompass AI VectorCode LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/Davidyz/VectorCode
--pip install "VectorCode[lsp,mcp]"
vim.lsp.config['vectorcode_ls'] = {
  cmd = {
    'vectorcode-server'
  },
  root_markers = {
    '.vectorcode',
    '.git'
  },
  settings = {},
}