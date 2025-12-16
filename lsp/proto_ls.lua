-- /qompassai/Diver/lsp/proto_ls.lua
-- Qompass AI Protobuf LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'protols',
  },
  filetypes = { ---@type string[]
    'proto',
  },
  root_markers = { ---@type string[]
    '.git',
  },
}