-- /qompassai/Diver/lsp/pug_ls.lua
-- Qompass AI Pug.js LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/opa-oz/pug-lsp
-- go install github.com/opa-oz/pug-lsp@latest
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'pug-lsp',
  },
  filetypes = { ---@type string[]
    'pug',
  },
  root_markers = { ---@type string[]
    'package.json',
  },
}