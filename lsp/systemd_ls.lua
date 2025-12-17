-- /qompassai/Diver/lsp/systemd_ls.lua
-- Qompass AI Systemd Language Server LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'systemd-language-server',
  },
  filetypes = { ---@type string[]
    'systemd',
  },
  root_markers = { ---@type string[]
    '.git'
  },
}