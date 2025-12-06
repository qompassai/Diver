-- /qompassai/Diver/lsp/kubescape_ls.lua
-- Qompass AI KubeScape LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['kubescape_ls'] = {
  cmd = {
    'kubescape'
  },
  filetypes = {
    'yaml',
    'yml',
    'json',
    'jsonc'
  },
  codeActionProvider = false,
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    kubescape = {},
  },
  single_file_support = true,
}