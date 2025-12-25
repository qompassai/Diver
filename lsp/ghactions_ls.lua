-- /qompassai/Diver/lsp/ghactions_ls.lua
-- Qompass AI Github Actions LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://github.com/lttb/gh-actions-language-server
-- pnpm add -g gh-actions-language-server
---@type vim.lsp.Config
return {
  cmd = {
    'gh-actions-language-server',
    '--stdio',
  },
  filetypes = {
    'yaml',
    'yml',
  },
  init_options = {},
  capabilities = {
    workspace = {
      didChangeWorkspaceFolders = {
        dynamicRegistration = true,
      },
    },
  },
}