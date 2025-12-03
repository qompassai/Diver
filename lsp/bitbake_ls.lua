-- /qompassai/Diver/lsp/bitbake_ls.lua
-- Qompass AI BitBake LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------
-- Reference:  https://github.com/Freed-Wu/bitbake-language-server
-- pip install bitbake-language-server
vim.lsp.config['bitbake-language-server'] = {
  cmd = {
    'bitbake-language-server' },
  filetypes = {
    'bitbake'
  },
  root_markers = { '.git' },
}