-- /qompassai/Diver/lsp/sqruff.lua
-- Qompass AI SQL Ruff LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://github.com/quarylabs/sqruff
-- Install: cargo install sqruff
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'sqruff',
    'lsp'
  },
  filetypes = { ---@type string[]
    'sql',
  },
  root_markers = { ---@type string[]
    '.sqruff',
    '.git'
  },
}