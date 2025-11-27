-- /qompassai/Diver/lsp/syntax_tree.lua
-- Qompass AI Syntax Tree LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- gem install syntax_tree
---@type vim.lsp.Config
return {
  cmd = { 'stree', 'lsp' },
  filetypes = { 'ruby' },
  root_markers = { '.streerc', 'Gemfile', '.git' },
}