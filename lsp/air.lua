-- /qompassai/Diver/lsp/air.lua
-- Qompass AI Air LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['air'] = {
  default_config = {
    cmd = { 'air' },
    filetypes = {
      'r'
    },
    root_dir = function(fname)
      return vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
    end,
    single_file_support = true,
  },
}