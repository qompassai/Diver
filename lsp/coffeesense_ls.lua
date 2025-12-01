-- /qmopassai/Diver/lsp/coffeesense_ls.lua
-- Qompass AI CoffeeSense LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- References:  https://github.com/phil294/coffeesense
-- pnpm add -g coffeesense-language-server
vim.lsp.config['coffeesense-language-server'] = {
  cmd = { 'coffeesense-language-server', '--stdio' },
  filetypes = { 'coffee' },
  root_markers = { 'package.json' },
}