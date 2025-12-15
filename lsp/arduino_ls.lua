-- /qompassai/Diver/lsp/arduino_ls.lua
-- Qompass AI Arduino LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  capabilities = {
    textDocument = {
      ---@diagnostic disable-next-line: assign-type-mismatch
      semanticTokens = vim.NIL,
    },
    cmd = {
      'arduino-language-server',
    },
    filetypes = {
      'arduino',
    },
    root_markers = {
      '*.ino'
    },
    workspace = {
      ---@diagnostic disable-next-line: assign-type-mismatch
      semanticTokens = vim.NIL,
    },
  }
}