-- /qompassai/Diver/lsp/hydra_ls.lua
-- Qompass AI Hydra LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference: https://github.com/Retsediv/hydra-lsp
--pip install hyrda-lsp
vim.lsp.config['hydra_ls'] = {
  cmd = {
    'hydra-lsp',
  },
  filetypes = {
    'yaml',
  },
  root_markers = { '.git' },
}