-- ruby_lsp.lua
-- Qompass AI
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['rubylsp'] = {
  default_config = {
    cmd = { "ruby-lsp" },
    filetypes = { "ruby" },
    root_dir = function(fname)
      return vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
    end,
    single_file_support = true,
  }
}