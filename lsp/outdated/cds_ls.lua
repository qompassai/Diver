-- cds_ls.lua
-- Qompass AI - [Add descriptio]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pnpm i -g @sap/cds-lsp
 vim.lsp.config = {
  cmd = {
        'cds-lsp',
        '--stdio' },
  filetypes = { 'cds' },
   init_options = {
        provideFormatter = true
    },
  root_markers = {
        'package.json',
        'db',
        'srv'
    },
  settings = {
    cds = {
            validate = true
        },
  },
}
