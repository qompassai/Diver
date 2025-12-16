-- /qompassai/Diver/lsp/postgrestoo_ls.lua
-- Qompass AI PostGresTools LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference:  https://pg-language-server.com
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'postgrestools',
    'lsp-proxy',
  },
  filetypes = { ---@type string[]
    'sql',
  },
  root_markers = { ---@type string[]
    'postgrestools.jsonc',
  },
  workspace_required = true, ---@type boolean
}