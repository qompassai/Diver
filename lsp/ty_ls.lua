-- /qompassai/Dive/lsp/ty_ls.lua
-- Qompass AI Diver Ty LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'ty',
    'server',
  },
  filetypes = { ---@type string[]
    'python',
  },
  root_markers = { ---@type string[]
    'ty.toml',
    'pyproject.toml',
    '.git',
  },
  settings = {
    ty = {
      disableLanguageServices = false,
      diagnosticMode = 'workspace',
      inlayHints = {
        variableTypes = true,
        callArgumentNames = true,
      },
      experimental = {
        rename = true,
        autoImport = true,
      },
    },
  },
  init_options = {
    logFile = '/tmp/ty-lsp.log',
    logLevel = 'info',
  },
}