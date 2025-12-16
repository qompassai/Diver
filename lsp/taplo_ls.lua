-- /qompassai/Diver/lsp/taplo.lua
-- Qompass AI Taplo LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'taplo',
    'lsp',
  },
  filetypes = { ---@type string[]
    'toml',
  },
  root_markers = { ---@type string[]
    '.taplo.toml',
    'taplo.toml',
    '.git',
  },
}