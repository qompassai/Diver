-- /qompassai/Diver/lsp/htmlhint.lua
-- Qompass AI HTML Hint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'htmlhint',
  },
  filetypes = {
    'html',
    'htm',
  },
  settings = {
    htmlhint = {},
  },
}