-- /qompassai/Diver/lsp/spectral_ls.lua
-- Qompass AI Spectral LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
vim.lsp.config['spectral_ls'] = {
  cmd = {
    'spectral-language-server',
    '--stdio'
  },
  filetypes = {
    'yaml',
    'json',
    'yml'
  },
  root_markers = {
    '.spectral.yaml',
    '.spectral.yml',
    '.spectral.json',
    '.spectral.js'
  },
  settings = {
    enable = true,
    run = 'onType',
    validateLanguages = {
      'yaml',
      'json',
      'yml'
    },
  },
}