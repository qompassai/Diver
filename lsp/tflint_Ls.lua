-- /qompassai/Diver/lsp/tflint.lua
-- Qompass AI Terraform Lint LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'tflint',
    '--langserver',
  },
  filetypes = { ---@type string[]
    'terraform',
  },
  root_markers = { ---@type string[]
    '.terraform',
    '.git',
    '.tflint.hcl',
  },
}