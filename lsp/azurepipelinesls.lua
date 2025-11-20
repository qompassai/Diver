-- /qompassai/Diver/lsp/azurepipelinesls.lua
-- Qompass AI Azure Pipelines LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- pnpm add -g azure-pipelines-language-service
vim.lsp.config['azure_pipelines_ls'] = {
  cmd = { "azure-pipelines-language-server", "--stdio" },
  filetypes = { 'yaml', 'yml' },
  root_markers = { "azure-pipelines.yml" },
  settings = {
    yaml = {
      schemas = {
        ["https://raw.githubusercontent.com/microsoft/azure-pipelines-vscode/master/service-schema.json"] = {
          "/azure-pipeline*.y*l",
          "/*.azure*",
          "Azure-Pipelines/**/*.y*l",
          "Pipelines/*.y*l",
        },
      },
    },
  },
}