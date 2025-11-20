-- /qompassai/Diver/lsp/angularls.lua
-- Qompass AI Angular LSP Spec (ngserver / angular-language-server)
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://angular.dev/tools/language-service
local project_library_path = vim.fn.getcwd() .. '/node_modules'
vim.lsp.config['angularls'] = {
  cmd = {
    project_library_path .. '/@angular/language-server/bin/ngserver',
    '--stdio',
    '--tsProbeLocations', project_library_path,
    '--ngProbeLocations', project_library_path,
     '--logFile', vim.fn.stdpath('cache') .. '/nglangsvc.log',
     '--logVerbosity', 'verbose',
  },
  filetypes = { 'typescript', 'typescriptreact', 'html', 'angular' },
  codeActionProvider = {
    codeActionKinds = { '', 'quickfix', 'refactor.extract', 'refactor.rewrite' },
    resolveProvider = true,
  },
  colorProvider = false,
  semanticTokensProvider = nil,
  settings = {
    angular = {
      suggest = {
        completeFunctionCalls = true,
      },
    },
  },
  flags = {
    debounce_text_changes = 150,
  },
  single_file_support = false,
}