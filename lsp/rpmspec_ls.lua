-- /qompassai/Diver/lsp/rpmspec_ls.lua
-- Qompass AI Redhat Package Manager (RPM) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
--Reference: https://github.com/dcermak/rpm-spec-language-server
-- pip install rpm-spec-language-server
vim.lsp.config['rpmspec'] = {
  cmd = {
    'rpm_lsp_server',
    '--stdio'
  },
  filetypes = {
    'spec'
  },
  root_markers = {
    '.git'
  },
  settings = { ... },
}