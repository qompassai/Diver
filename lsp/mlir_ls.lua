-- /qompassai/Diver/lsp/mlir_ls.lua
-- Qompass AI Multi-Level Intermediate Representation (MLIR) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'mlir-lsp-server'
  },
  filetypes = { ---@type string[]
    'mlir'
  },
  root_markers = { ---@type string[]
    '.git'
  },
}