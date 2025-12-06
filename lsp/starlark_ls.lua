-- /qompassai/Diver/lsp/starlark_ls.lua
-- Qompass AI Starlark LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['starlark'] = {
  cmd = {
    'starlark',
    '--lsp'
  },
  filetypes = {
    'star',
    'bzl',
    'BUILD.bazel'
  },
  root_markers = {
    '.git'
  },
}