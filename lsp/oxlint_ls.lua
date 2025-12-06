-- /qompassai/Diver/lsp/oxlint_ls.lua
-- Qompass AI Javascript Oxidation Lint (oxlint) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- References: https://www.npmjs.com/package/oxlint | https://oxc.rs/docs/guide/usage/linter/cli.html
vim.lsp.config['oxlint_ls'] = {
  cmd = {
    'oxc_language_server',
    '-D',
    'correctness',
    '-D',
    'suspicious',
    '-W',
    'style',
    '--type-aware',
    '--type-check',
    '--import-plugin',
    '--react-plugin',
    '--tsconfig=tsconfig.json',
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  workspace_required = true,
  root_markers = {
    '.oxlintrc.json',
    'oxlint'
  }
}