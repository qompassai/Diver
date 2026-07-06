-- /qompassai/Diver/lsp/flow_ls.lua
-- Qompass AI Diver Flow LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@source  https://github.com/facebook/flow
---@type vim.lsp.Config
return {
  cmd = {
    'npx',
    '--no-install',
    'flow',
    'lsp',
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx',
  },
  root_markers = {
    '.flowconfig',
  },
}
