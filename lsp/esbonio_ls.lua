-- /qompassai/Diver/lsp/esbonio.lua
-- Qompass AI Diver Esbonio LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'esbonio',
  },
  settings = {
    esbonio = {
      server = {
        logLevel = 'debug',
        timeout = 10,
      },
      sphinx = {
        enabled = true,
        builder = 'html',
        confDir = '${workspaceFolder}',
        srcDir = 'docs',
        buildDir = 'build',
        doctreeDir = 'build/.doctrees',
        pythonPath = {},
      },
      docutils = {
        enabled = true,
        strict = true,
      },
      completion = {
        enabled = true,
      },
      diagnostics = {
        enabled = true,
      },
      preview = {
        enabled = true,
      },
    },
  },
  filetypes = { ---@type string[]
    'rst',
    'rest',
    'restructuredtext',
  },
}