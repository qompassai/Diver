-- /qompassai/Diver/lsp/stylelint_ls.lua
-- Qompass AI Stylelint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/bmatcuk/stylelint-lsp
-- pnpm add -g stylelint-lsp
vim.lsp.config['stylelint_ls'] = {
  cmd = {
    'stylelint-lsp',
    '--stdio',
  },
  filetypes = {
    'astro',
    'css',
    'html',
    'less',
    'scss',
    'sugarss',
    'vue',
    'wxss',
  },
  root_markers = {
    '.stylelintrc',
    '.stylelintrc.mjs',
    '.stylelintrc.cjs',
    '.stylelintrc.js',
    '.stylelintrc.json',
    '.stylelintrc.yaml',
    '.stylelintrc.yml',
    'stylelint.config.mjs',
    'stylelint.config.cjs',
    'stylelint.config.js',
  },
  settings = {
    stylelintplus = {
      enable = true,
      autoFixOnFormat = true,
      autoFixOnSave = false,
      validateOnSave = true,
      validateOnType = true,
      config = nil,
      configFile = nil,
    },
  },
}