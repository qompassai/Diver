-- /qompassai/Diver/lsp/azurepipelinesls.lua
-- Qompass AI Azure Pipelines LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
vim.lsp.config['azurepipelines_ls'] = {
  cmd = {
    'pnpm',
    'exec',
    'azure-pipelines-language-server',
    '--stdio'
  },
  filetypes = {
    'yaml',
    'yml'
  },
  root_markers = {
    'azure-pipelines.yml',
    '.git'
  },
  settings = {
    yaml = {
      customTags = {},
      completion = true,
      format = {
        enable = true,
        singleQuote = true,
        bracketSpacing = true,
        proseWrap = 'preserve',
      },
      hover = true,
      keyOrdering = true,
      schemaStore = {
        enable = true,
        url = 'https://www.schemastore.org/api/json/catalog.json',
      },
      schemas = {
        ['https://json.schemastore.org/azure-pipelines.json'] = {
          'azure-pipelines.yml',
          'azure-pipelines.yaml',
          'azure-pipeline*.yml',
          'azure-pipeline*.yaml',
          '*.azure*',
          'Azure-Pipelines/**/*.y*l',
          'Pipelines/**/*.y*l',
        },
      },
      schemaValidation = true,
      validate = true,
    },
  },
}