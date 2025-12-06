-- /qompassai/Diver/lsp/solargraph_ls.lua
-- Qompass AI Solargraph LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- References:  https://solargaraph.org/
-- gem install --user-install solargraph
vim.lsp.config['solargraph'] = {
  cmd = {
    'solargraph',
    'stdio'
  },
  settings = {
    solargraph = {
      diagnostics = true,
    },
  },
  init_options = {
    formatting = true
  },
  filetypes = {
    'ruby'
  },
  root_markers = {
    'Gemfile',
    '.git'
  },
}