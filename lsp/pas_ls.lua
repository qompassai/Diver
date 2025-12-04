-- /qompassai/Diver/lsp/pas_ls.lua
-- Qompass AI Pascal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/genericptr/pascal-language-server
vim.lsp.config['pascal'] = {
  cmd = {
    'pasls'
  },
  filetypes = {
    'pascal'
  },
  root_markers = {
    '*.lpi',
    '*.lpk',
    '.git'
  }
}