-- /qompassai/Diver/lsp/vectorcode_ls.lua
-- Qompass AI VectorCode LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://github.com/Davidyz/VectorCode
--pip install "VectorCode[lsp,mcp]"
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'vectorcode-server'
  },
  root_markers = { ---@type string[]
    '.vectorcode',
    '.git'
  },
  settings = {}, ---@type string[]
}