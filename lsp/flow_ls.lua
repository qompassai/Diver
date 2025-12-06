-- /qompassai/Diver/lsp/flow_ls.lua
-- Qompass AI Flow LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://github.com/facebook/flow
vim.lsp.config['flow_ls'] = {
  cmd = {
    'npx',
    '--no-install',
    'flow',
    'lsp'
  },
  filetypes = {
    'javascript',
    'javascriptreact',
    'javascript.jsx'
  },
  root_markers = {
    '.flowconfig'
  },
}