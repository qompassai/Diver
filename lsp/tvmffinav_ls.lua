-- /qompassai/Diver/lsp/tvmffi_navigator.lua
-- Qompass AI TVM FFI Navigator LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/tqchen/ffi-navigator
--pip install ffi-navigator
vim.lsp.config['tvmffinav_ls'] = {
  cmd = {
    'python',
    '-m',
    'ffi_navigator.langserver'
  },
  filetypes = {
    'python',
    'cpp'
  },
  root_markers = {
    'pyproject.toml',
    '.git'
  },
}