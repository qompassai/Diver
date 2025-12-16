-- /qompassai/Diver/lsp/cucumber_ls.lua
-- Qompass AI Diver Cucumber LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'cucumber-language-server',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'cucumber',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}