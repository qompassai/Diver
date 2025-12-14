-- /qompassai/Diver/lsp/bitbake_ls.lua
-- Qompass AI BitBake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------
vim.lsp.config['bitbake_ls'] = {
  cmd = {
    'bitbake-language-server',
  },
  filetypes = {
    'bitbake',
  },
  root_markers = { '.git' },
}