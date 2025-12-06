-- /qompassai/Diver/lsp/cds_ls.lua
-- Qompass AI Core Data Services (CDS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://cap.cloud.sap/docs/
--pnpm add -g @sap/cds-lsp
vim.lsp.config['cds_ls'] = {
  cmd = {
    'cds-lsp',
    '--stdio'
  },
  filetypes = {
    'cds'
  },
  init_options = {
    provideFormatter = true
  },
  root_markers = {
    'db',
    'package.json',
    'srv'
  },
  settings = {
    cds = {
      validate = true
    },
  },
}