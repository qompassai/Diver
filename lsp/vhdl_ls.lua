-- /qompassai/Diver/lsp/vhdl_ls.lua
-- Qompass AI VHSIC Hardware Description Language (VHDL) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------------------
--Reference: https://github.com/VHDL-LS/rust_hdl
--cargo install vhdl_ls
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'vhdl_ls',
  },
  filetypes = { ---@type string[]
    'vhd',
    'vhdl',
  },
  root_markers = { ---@type string[]
    'vhdl_ls.toml',
    '.vhdl_ls.toml',
  },
}