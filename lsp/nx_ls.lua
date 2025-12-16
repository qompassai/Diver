-- /qompassai/Diver/lsp/nx_ls.lua
-- Qompass AI NX Workspace LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'nxls',
    '--stdio',
  },
  filetypes = { ---@type string[]
    'json',
    'jsonc',
  },
  root_markers = { ---@type string[]
    'nx.jsonc',
    'workspace.jsonc',
    'project.jsonc',
    '.git',
  },
}