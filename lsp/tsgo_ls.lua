-- /qompassai/Diver/lsp/tsgo.lua
-- Qompass AI Typescript-Go LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- pnpm add -g  @typescript/native-preview@latest
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'tsgo',
    '--lsp',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'javascript',
    'javascript.jsx',
    'javascriptreact',
    'typescript',
    'typescriptreact',
    'typescript.tsx',
  },
  root_markers = { ---@type string[]
    'bun.lockb',
    'bun.lock',
    '.git',
    'package.json',
    'package.jsonc',
    'package-lock.json',
    'package-lock.jsonc',
    'pnpm-lock.yaml',
    'yarn.lock',
  },
}