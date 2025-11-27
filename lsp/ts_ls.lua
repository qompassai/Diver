-- /qompassai/Diver/lsp/ts_ls.lua
-- Qompass AI Typescript LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

vim.lsp.config['ts_ls'] = {
  default_config = {
    init_options = { hostInfo = 'neovim' },
    cmd = { 'typescript-language-server', '--stdio' },
    filetypes = {
      'javascript',
      'javascriptreact',
      'javascript.jsx',
      'typescript',
      'typescriptreact',
      'typescript.tsx',
    },
    root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' },
    single_file_support = true,
  },
}