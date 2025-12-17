-- /qompassai/Diver/lsp/ungrammar_ls.lua
-- Qompass AI UnGrammar LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/binhtran432k/ungrammar-language-features
-- pnpm add -g ungrammar-languageserver@lastest
---@type vim.lsp.Config
return {
  cmd = {
    'ungrammar-languageserver',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'ungrammar',
  },
  root_markers = { ---@type string[]
    '.git',
  },
  settings = {
    ungrammar = {
      validate = {
        enable = true,
      },
      format = {
        enable = true,
      },
    },
  },
}