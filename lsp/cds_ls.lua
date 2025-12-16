-- /qompassai/Diver/lsp/cds_ls.lua
-- Qompass AI Core Data Services (CDS) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'cds-lsp',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'cds',
  },
  init_options = {
    provideFormatter = true,
  },
  root_markers = {
    'db',
    'package.json',
    'srv',
  },
  settings = {
    cds = {
      validate = true,
    },
  },
}