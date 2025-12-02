-- /qompassai/Diver/lsp/nil_ls.lua
-- Qompass AI Nix LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['nil_ls'] = {
  autostart = true,
  cmd = {
    'nil',
    '--stdio'
  },
  filetypes = {
    'nix',
  },
  root_markers = {
    'default.nix',
    'flake.nix',
    '.git'
  },
  settings = {
    ['nil'] = {
      formatting = {
        command = {
          'alejandra',
          '--'
        },
      },
      diagnostics = {
        enabled = true,
        ignored = {},
        excludedFiles = {},
      },
      nix = {
        flake = {
          autoArchive = true,
          autoEvalInputs = true,
        },
        autoLSPConfig = true,
        testSetting = 42,
      },
    },
  },
}