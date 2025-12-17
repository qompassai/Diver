-- /qompassai/Diver/lsp/regal_ls.lua
-- Qompass AI Regal LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- Reference: https://github.com/StyraInc/regal
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'regal',
    'language-server',
  },
  filetypes = { ---@type string[]
    'rego'
  },
  root_markers = { ---@type string[]
    '.git',
  },
}