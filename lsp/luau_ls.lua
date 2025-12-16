-- /qompassai/Diver/lsp/luau_ls.lua
-- Qompass AI Luau LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'luau-lsp',
    'lsp',
  },
  filetypes = { ---@type string[]
    'luau',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}