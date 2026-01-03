-- /qompassai/Diver/lsp/pico8_ls.lua
-- Qompass AI Pico8 LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'pico8-ls',
    '--stdio'
  },
  filetypes = {
    'pico8',
    'lua'
  },
  root_markers = {
    '.git',
    '.p8'
  },
}