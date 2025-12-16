-- /qompassai/Diver/lsp/svls.lua
-- Qompass AI SVLS SystemVerilog LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'svls',
  },
  filetypes = { ---@type string[]
    'verilog',
    'systemverilog',
  },
}