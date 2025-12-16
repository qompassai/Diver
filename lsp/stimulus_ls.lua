-- /qompassai/Diver/lsp/stimulus_ls.lua
-- Qompass AI Stimulus LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference: https://www.npmjs.com/package/stimulus-language-server
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'stimulus-language-server',
  },
  filetypes = { ---@type string[]
    'blade',
    'eruby',
    'html',
    'php',
    'ruby',
  },
  root_markers = { ---@type string[]
    'Gemfile',
    '.git',
  },
}