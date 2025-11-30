-- /qompassai/Diver/lsp/angularls.lua
-- Qompass AI Angular LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Reference: https://angular.dev/tools/language-service
-- pnpm add -g @angular/language-server
local ngserver_path = "pnpm_global_node_modules" .. "/@angular/language-server/bin/ngserver"
vim.lsp.config["angularls"] = {
  cmd = {
    "node",
    ngserver_path,
    "--stdio",
    "--tsProbeLocations",
    "pnpm_global_node_modules",
    "--ngProbeLocations",
    "pnpm_global_node_modules",
    "--logFile",
    vim.fn.stdpath("cache") .. "/nglangsvc.log",
    "--logVerbosity",
    "verbose",
  },
  filetypes = { "typescript", "typescriptreact", "html", "angular" },
  codeActionProvider = {
    codeActionKinds = { "", "quickfix", "refactor.extract", "refactor.rewrite" },
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
}
