-- /qompassai/Diver/lsp/prose_ls.lua
-- Qompass AI ProseMD LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
--Reference:
--cargo install --git  https://github.com/kitten/prosemd-lsp prosemd-lsp
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'prosemd-lsp',
    '--stdio'
  },
  filetypes = { ---@type string[]
    'markdown',
  },
  root_markers = { ---@type string[]
    '.git',
  },
  settings = {
    prosemd = {
      validate = true ---@type boolean
    },
  },
}