-- /qompassai/Diver/lsp/ghdl_ls.lua
-- Qompass AI GHDL VHDL LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- https://github.com/ghdl/ghdl/tree/master/pyGHDL/lsp
-- pip install --user pyTooling pyVHDLModel pyVHDLParser
-- git clone https://github.com/ghdl/ghdl.git
-- cd ghdl && pip install .
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'ghdl-ls'
  },
  filetypes = { ---@type string[]
    'vhdl',
    'vhd'
  },
  root_markers = { ---@type string[]
    'hdl-prj.json',
    '.git'
  },
}