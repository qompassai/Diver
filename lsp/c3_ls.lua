-- /qompassai/Diver/lsp/c3_ls.lua
-- Qompass AI C3 LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- References: https://github.com/pherrymason/c3-lsp?tab=readme-ov-file#Installation |
-- https://github.com/pherrymason/c3-lsp/wiki/Integration-with-editors
-- yay/apt/dnf c3-lsp
vim.cmd [[autocmd BufNewFile,BufRead *.c3 set filetype=c3]]
vim.lsp.config['c3-lsp'] = {
  cmd = {
    'c3lsp',
    '--send-reports=false',
    '--lang-version=latest'
  },
  filetypes = {
    'c3'
  },
  root_markers = {
    '.git',
    'c3.toml',
  },
  init_options = {
  },
}