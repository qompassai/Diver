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
  root_markers = { ---@type string[]
    'default.nix',
    'flake.nix',
    '.git',
  },
  settings = {
    ['nil'] = {
      formatting = {
        command = { ---@type string[]
          'alejandra',
        },
      },
      diagnostics = {
        enabled = true, ---@type boolean
        ignored = {},
        excludedFiles = {},
      },
      nix = {
        flake = { ---@type boolean[]
          autoArchive = true,
          autoEvalInputs = true,
        },
        testSetting = 42, ---@type integer
      },
    },
  }
}