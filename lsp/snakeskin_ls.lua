-- /qompassai/Diver/lsp/snakeskin_ls.lua
-- Qompass AI SnakeSkin LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ------------------------------------------------------
-- Reference: https://www.npmjs.com/package/@snakeskin/cli
-- pnpm add -g @snakeskin/cli@latest
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'snakeskin-cli',
    'lsp',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'ss',
  },
  root_markers = { ---@type string[]
    'package.json',
    'package.jsonc'
  },
}