-- /qompassai/Diver/lsp/customelements_ls.lua
-- Qompass AI Custom Elements LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  init_options = {
    hostInfo = 'neovim',
  },
  cmd = { ---@type string[]
    'custom-elements-languageserver',
    '--stdio',
  },
  root_markers = { ---@type string[]
    'tsconfig.json',
    'package.json',
    'jsconfig.json',
    '.git',
  },
}