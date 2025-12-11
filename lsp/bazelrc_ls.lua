-- /qompassai/Diver/lsp/bazelrc_ls.lua
-- Qompass AI GHDL Bazelrc LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g git+https://github.com/salesforce-misc/bazelrc-lsp.git
vim.filetype.add {
  pattern = {
    ['.*.bazelrc'] = 'bazelrc',
  },
}
vim.lsp.config['bazelrc_ls'] = {
  cmd = {
    'bazelrc-lsp',
  },
  filetypes = {
    'bazelrc',
  },
  root_markers = {
    ".git",
    ".bazelrc",
  },
}