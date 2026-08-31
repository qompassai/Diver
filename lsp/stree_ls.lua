-- /qompassai/Diver/lsp/stree_ls.lua
-- Qompass AI Syntax Tree LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://ruby-syntax-tree.github.io/syntax_tree/
---@type vim.lsp.Config
return {
  cmd = {
    'stree',
    'lsp',
  },
  filetypes = {
    'ruby',
  },
  root_markers = {
    'Gemfile',
    '.git',
    '.streerc',
  },
  settings = {},
}
