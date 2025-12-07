-- /qompassai/Diver/lsp/rescript_ls.lua
-- Qompass AI Rescript LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pnpm add -g @rescript/language-server
-- Reference: https://github.com/rescript-lang/rescript-vscode/tree/master/server
vim.lsp.config['rescript_ls'] = {
  cmd = {
    'rescript-language-server',
    '--stdio'
  },
  filetypes = {
    'rescript'
  },
  root_markers = {
    'bsconfig.json',
    'rescript.json',
    '.git'
  },
  settings = {},
  init_options = {
    extensionConfiguration = {
      askToStartBuild = false,

      allowBuiltInFormatter = true,
      incrementalTypechecking = {
        enabled = true,
        acrossFiles = true,
      },
      cache = {
        projectConfig = {
          enabled = true
        }
      },
      capabilities = {
        workspace = {
          didChangeWatchedFiles = {
            dynamicRegistration = true,
          },
        },
      },
      codeLens = true,
      inlayHints = {
        enable = true
      },
    },
  },
}