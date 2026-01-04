-- /qompassai/diver/lsp/visualforce_ls.lua
-- Qompass AI Visualforce LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------

return ---@type vim.lsp.Config
{
  ft = {
    'visualforce'
  },
  root_markers = { 'sfdx-project.json' },
  init_options = {
    embeddedLanguages = {
      css = true,
      javascript = true,
    },
  },
}