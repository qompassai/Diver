-- /qompassai/Diver/lsp/bzl_ls.lua
-- Qompass AI Bazel LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = {
    'bzl',
    'lsp',
    'serve',
  },
  filetypes = {
    'bzl',
  },
  root_markers = {
    'WORKSPACE',
    'WORKSPACE.bazel',
  },
}