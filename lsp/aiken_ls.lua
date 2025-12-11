-- /qompassai/Diver/lsp/aiken_l.lua
-- Qompass AI Aiken LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['aiken_ls'] = {
  cmd = { 'aiken', 'lsp' },
  filetypes = { 'aiken' },
  root_markers = { 'aiken.toml', '.git' },
}