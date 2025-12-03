-- /qompassai/Diver/lsp/just_ls.lua
-- Qompass AI Just LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/terror/just-lsp
-- cargo install just-lsp
vim.lsp.config['just-lsp'] = {
  cmd = {
    'just-lsp'
  },
  filetypes = {
    'just'
  },
  root_markers = { '.git' },
}