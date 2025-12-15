-- /qompassai/Diver/lsp/beancount_ls.lua
-- Qompass AI Beancount LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.filetype.add({
  extension = {
    beancount = 'beancount',
    bean = 'beancount',
  },
})
---@type vim.lsp.Config
return {
  cmd = {
    'beancount-language-server',
    '--stdio',
  },
  filetypes = {
    'beancount',
  },
  init_options = {
    journal_file = '',
    formatting = {
      prefix_width = 30,
      currency_column = 60,
      number_currency_spacing = 1,
    },
  },
  root_markers = {
    'main.bean',
    'beancount.conf',
    '.git',
  },
}