-- /qompassai/Diver/lsp/postgres_ls.lua
-- Qompass AI Postgres LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- References:  https://pgtools.net
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'postgres-language-server',
    'lsp-proxy',
  },
  filetypes = { ---@type string[]
    'sql',
    'psql',
  },
  root_markers = { ---@type string[]
    'postgres-language-server.jsonc'
  },
  workspace_required = true,
}