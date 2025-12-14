-- /qompassai/Dive/lsp/ty_ls.lua
-- Qompass AI TY LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['ty_ls'] = {
  cmd = {
    'ty',
    'server'
  },
  filetypes = {
    'python'
  },
  root_markers = {
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