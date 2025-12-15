-- /qompassai/Diver/lsp/angularls.lua
-- Qompass AI Angular LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://angular.dev/tools/language-service
-- pnpm add -g @angular/language-server@latest
local npm_root = vim.fn.systemlist('npm root -g')[1]
local ngserver_path = 'pnpm_global_node_modules' .. '/@angular/language-server/bin/ngserver'
return {
  cmd = {
    'ngserver',
    '--stdio',
    '--tsProbeLocations',
    npm_root,
    '--ngProbeLocations',
    npm_root,
  },
  filetypes = {
    'typescript',
    'typescriptreact',
    'typescript.tsx',
    'html',
  },
  root_markers = {
    'angular.json',
    'workspace.json',
    'project.json',
    'nx.json',
    'package.json',
    '.git',
  },
}