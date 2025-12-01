-- /qompassai/Diver/lsp/tsgo.lua
-- Qompass AI TS GO LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pnpm add -g  @typescript/native-preview
vim.lsp.config['tsgo'] = {
  cmd = {
    "tsgo",
    "--lsp",
    "--stdio",
  },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  root_markers = {
    "package.json",
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "bun.lockb",
    "bun.lock",
    ".git",
  },
}