-- /qompassai/Diver/lsp/stimulus_ls.lua
-- Qompass AI Stimulus LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://www.npmjs.com/package/stimulus-language-server
--pnpm add -g stimulus-language-server
vim.lsp.config['stimulus_ls'] = {
  cmd = {
    'stimulus-language-server',
    '--stdio'
  },
  filetypes = {
    'blade',
    'eruby',
    'html',
    'php',
    'ruby'
  },
  root_markers = {
    'Gemfile',
    '.git'
  },
}