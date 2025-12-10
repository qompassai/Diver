-- /qompassai/Diver/lsp/agda_ls
-- Qompass AI Agda LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

vim.lsp.config['agda_ls'] = {
  cmd = { 'als' },
  filetypes = { 'agda' },
  root_markers = { '*.agda_lib', '.git' },
}