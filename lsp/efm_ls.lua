-- /qompassai/Diver/lsp/efm_ls.lua
-- Qompass AI EFM LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['efm_ls'] = {
  cmd = {
    'efm-langserver',
  },
  filetypes = {
    'c',
    'cpp',
    'go',
    'json',
    'lua',
    'markdown',
    'python',
    'sh',
    'yaml',
  },
  init_options = {
    documentFormatting = true,
    hover = true,
    lintDebounce = 100,
    lintOnChange = true,
    lintOnSave = true,
    completion = true,
  },
  root_markers = {
    '.git',
    '.hg',
    '.svn',
  },
}