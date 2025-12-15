-- /qompassai/Diver/lsp/rescript_ls.lua
-- Qompass AI Rescript LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
  cmd = {
    'rescript-language-server',
    '--stdio',
  },
  filetypes = {
    'rescript',
  },
  root_markers = {
    'bsconfig.json',
    'rescript.json',
    '.git',
  },
  settings = {
    cache = {
      projectConfig = {
        enabled = true,
      },
      capabilities = {
        workspace = {
          didChangeWatchedFiles = {
            dynamicRegistration = true,
          },
        },
      },
      codeLens = true,
      init_options = {
        extensionConfiguration = {
          allowBuiltInFormatter = true,
          askToStartBuild = false,
          incrementalTypechecking = {
            enabled = true,
            acrossFiles = true,
          },
        },
        inlayHints = {
          enable = true,
        },
      },
    },
  },
}