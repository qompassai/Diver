-- /qompassai/Diver/lsp/jsonnet_ls.lua
-- Qompass AI JSonnet LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/grafana/jsonnet-language-server
--  go install github.com/grafana/jsonnet-language-server@latest
vim.lsp.config['jsonnet_ls'] = {
  cmd = {
    'jsonnet-language-server'
  },
  filetypes = {
    'jsonnet',
    'libsonnet',
  },
  root_markers = {
    'jsonnetfile.json',
    '.git'
  },
}