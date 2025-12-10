-- /qompassai/Diver/lsp/yaml_ls.lua
-- Qompass AI Yamlls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['yaml_ls'] = {
  cmd = {
    'yaml-language-server',
    '--stdio',
  },
  filetypes = {
    'yaml',
    'yml',
    'yaml.docker-compose',
    'yaml.gitlab',
    'yaml.helm-values',
  },
  root_markers = {
    '.git',
  },
  settings = {
    redhat = {
      telemetry = {
        enabled = false,
      },
    },
    yaml = {
      format = {
        enable = true,
      },
      schemas = {
        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
      },
    },
  },
  on_init = function(client, _)
    client.server_capabilities.documentFormattingProvider = true
  end,
}