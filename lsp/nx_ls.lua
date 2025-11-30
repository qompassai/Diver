-- nx_ls.lua
-- Qompass AI NX Server
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
-- pnpm add -g nxls
vim.lsp.config['nx_ls'] = {
  autostart = true,
  cmd = {
    'nxls',
    '--stdio'
  },
  filetypes = {
    'json',
    'jsonc'
  },
  root_markers = {
    'nx.json',
    "workspace.json",
    "project.json",
    ".git"
  },
  settings = {
    nx = {
      enableWorkspaceSymbols = true,
      enableCodeActions = true,
      enableCodeLens = true,
      logLevel = "info",
    },
  },
  init_options = {
    workspaceJson = "workspace.json",
    nxJson = "nx.json",
    projectJson = "project.json",
  },
  ""
}