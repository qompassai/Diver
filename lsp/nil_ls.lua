-- /qompassai/Diver/lsp/nil_ls.lua
-- Qompass AI Nix LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'nil',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'nix',
  },
  root_markers = {
    'default.nix',
    'flake.nix',
    '.git',
  },
  settings = {
    ['nil'] = {
      formatting = {
        command = {
          'alejandra',
        },
      },
      diagnostics = {
        enabled = true,
        ignored = {},
        excludedFiles = {},
      },
      nix = {
        autoArchive = true,
        autoEvalInputs = true,
        binary = 'nix',
        flake = {
          autoArchive = true,
          autoEvalInputs = true,
        },
        maxMemoryMB = 2560,
        nixpkgsInputName = 'nixpkgs',
      },
    },
  },
}