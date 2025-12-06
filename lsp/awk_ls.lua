-- /qompassai/Diver/lsp/awk_ls.lua
-- Qompass AI Awk_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
--Reference:  https://github.com/Beaglefoot/awk-language-server/
--pnpm add -g awk-language-server
vim.lsp.config['awk_ls'] = {
  cmd = {
    'awk-language-server' },
  filetypes = {
    'awk'
  },
}