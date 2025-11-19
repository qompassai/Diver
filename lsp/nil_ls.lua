-- /qompassai/Diver/lsp/nil_ls.lua
-- Qompass AI Nix LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['nil_ls'] = {
  autostart = true,
  cmd = {
    'nil'
  },
  filetypes = {
    'nix'
  },
  root_markers = { 'flake.nix', '.git' },
  settings = {
    ['nil'] = {
      formatting = {
        command = 'nixpkgs-fmt',
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
      },
    },
  },
}