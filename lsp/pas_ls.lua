-- /qompassai/Diver/lsp/pas_ls.lua
-- Qompass AI Pascal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/genericptr/pascal-language-server
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'pasls',
  },
  filetypes = { ---@type string[]
    'pascal',
  },
  root_markers = { ---@type string[]
    '*.lpi',
    '*.lpk',
    '.git',
  },
}