-- /qompassai/Diver/lsp/syntax_tree.lua
-- Qompass AI Syntax Tree LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://ruby-syntax-tree.github.io/syntax_tree/
-- gem install syntax_tree
vim.lsp.config['stree'] = {
  cmd = {
    'stree',
    'lsp'
  },
  filetypes = {
    'ruby'
  },
  root_markers = {
    'Gemfile',
    '.git',
    '.streerc'
  },
}