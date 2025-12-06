-- /qompassai/Diver/lsp/nx_ls.lua
-- Qompass AI NX Workspace LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
--Reference: https://github.com/nrwl/nx-console/tree/master/apps/nxls
-- pnpm add -g nxls
vim.lsp.config['nx_ls'] = {
  cmd = {
    'nxls',
    '--stdio',
  },
  filetypes = {
    'json',
    'jsonc',
  },
  root_markers = {
    'nx.jsonc',
    'workspace.jsonc',
    'project.jsonc',
    '.git',
  },
  settings = {
    nx = {
      enableWorkspaceSymbols = true,
      enableCodeActions = true,
      enableCodeLens = true,
      logLevel = 'info',
    },
  },
  init_options = {
    workspaceJson = 'workspace.jsonc',
    nxJson = 'nx.jsonc',
    projectJson = 'project.jsonc',
  },
  '',
}