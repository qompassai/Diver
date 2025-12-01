-- /qompassai/Diver/lsp/bzl_ls.lua
-- Qompass AI Bazel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['bzl'] = {
  cmd = {
    'bzl',
    'lsp',
    'serve'
  },
  filetypes = {
    'bzl'
  },
  root_markers = {
    'WORKSPACE',
    'WORKSPACE.bazel'
  },
}