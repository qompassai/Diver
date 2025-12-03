-- /qompassai/Diver/lsp/vhdl_ls.lua
-- Qompass AI VHSIC Hardware Description Language (VHDL) LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------------------
--Reference: https://github.com/VHDL-LS/rust_hdl
--cargo install vhdl_ls
vim.lsp.config['vhdl_ls'] = {
  cmd = {
    'vhdl_ls'
  },
  filetypes = {
    'vhd',
    'vhdl' },
  root_markers = {
    'vhdl_ls.toml',
    '.vhdl_ls.toml',
  },
}