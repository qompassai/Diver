-- /qompassai/Diver/lsp/flow_ls.lua
-- Qompass AI Flow LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://github.com/facebook/flow
---@type vim.lsp.Config
return {
  cmd = { ---@type string[]
    'npx',
    '--no-install',
    'flow',
    'lsp',
  },
  filetypes = { ---@type string[]
    'javascript',
    'javascriptreact',
    'javascript.jsx',
  },
  root_markers = { ---@type string[]
    '.flowconfig',
  },
}