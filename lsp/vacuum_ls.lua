-- /qompassai/Diver/lsp/vacuum_ls.lua
-- Qompass AI Vacuum LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/daveshanley/vacuum
vim.filetype.add({
  pattern = {
    ['openapi.*%.ya?ml'] = 'yaml.openapi',
    ['openapi.*%.json'] = 'json.openapi',
  },
})
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'vacuum',
    'language-server',
  },
  filetypes = { ---@type string[]
    'yaml.openapi',
    'json.openapi',
  },
  root_markers = { ---@type string[]
    '.git'
  },
}