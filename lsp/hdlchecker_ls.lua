-- hdlchecker_ls.lua
-- Qompass AI - [ ]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lsp.Config
return {
  cmd = { 'hdl_checker', '--lsp' },
  filetypes = { 'vhdl', 'verilog', 'systemverilog' },
  root_markers = { '.git' },
}