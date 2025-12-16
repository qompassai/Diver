-- /qompassai/Diver/lsp/verible.lua
-- Qompass AI Verible SystemVerilog LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'verible-verilog-ls',
  },
  filetypes = { ---@type string[]
    'verilog',
    'systemverilog',
  },
  root_markers = { ---@type string[]
    '.git'
  },
}