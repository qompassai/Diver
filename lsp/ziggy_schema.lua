-- /qompassai/Diver/lsp/ziggy_schema.lua
-- Qompass AI Ziggy Schema Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--Reference:  https://ziggy-lang.io/documentation/ziggy-lsp/
vim.lsp.config['ziggy_schema'] = {
  cmd = {
    'ziggy',
    'lsp',
    '--schema'
  },
  filetypes = {
    'ziggy_schema'
  },
  root_markers = { ".git" },
}