-- /qompassai/Diver/lsp/mutt_ls.lua
-- Qompass AI - Mutt Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['mutt_ls'] = {
  cmd = {
    'mutt-language-server',
    '--color=always',
  },
  filetypes = {
    'muttrc',
    'neomuttrc',
  },
  root_markers = {
    '.git',
    '.mutt',
    '.neomutt',
    '.config/mutt',
    '.config/neomutt',
  },
}