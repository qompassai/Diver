-- buck2_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/facebook/buck2 | https://buck2.build/docs/getting_started/install/
-- rustup install nightly-2025-08-01
-- cargo +nightly-2025-08-01 install --git https://github.com/facebook/buck2.git buck2
vim.cmd [[ autocmd BufRead,BufNewFile *.bxl,BUCK,TARGETS set filetype=bzl ]]
vim.lsp.config['buck2'] = {
  cmd = {
    'buck2',
    'lsp'
  },
  filetypes = {
    'bzl'
  },
  root_markers = {
    '.buckconfig'
  },
}