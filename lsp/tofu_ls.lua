-- /qompassai/Diver/lsp/tofu_ls.lua
-- Qompass AI Diver OpenTofu LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- Reference: https://github.com/opentofu/tofu-ls
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'tofu-ls',
  },
  filetypes = { ---@type string[]
    'terraform',
    'opentofu',
    'opentofu-vars'
  },
  root_markers = { ---@type string[]
    '.git',
    '.terraform',
  },
}