-- /qompassai/Diver/lsp/intelephense.lua
-- Qompass AI Intelephense LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://intelephense.com |  https://github.com/bmewburn/intelephense-docs/blob/master/installation.md#initialisation-options
-- pnpm add -g intelephense
vim.lsp.config['intelephense'] = {
  cmd = {
    'intelephense',
    '--stdio',
  },
  filetypes = {
    'php'
  },
  root_markers = {
    '.git',
    'composer.json',
  },
  settings = {
    intelephense = {
      files = {
        maxSize = 1000000,
      },
    },
  },
}