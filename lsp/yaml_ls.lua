-- /qompassai/Diver/lsp/yaml_ls.lua
-- Qompass AI Yamlls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
vim.lsp.config['yaml_ls'] = {
  cmd = {
    'yaml-language-server',
    '--stdio'
  },
  filetypes = {
    'yaml',
    'yml',
    'yaml.docker-compose',
    'yaml.gitlab',
    'yaml.helm-values',
  },
  root_markers = {
    '.git'
  },
  settings = {
    redhat = {
      telemetry = {
        enabled = false
      },
    },
    yaml = {
      format = {
        enable = true,
      },
      schemas = {
        ['https://json.schemastore.org/github-workflow.json'] = '/.github/workflows/*',
        ['https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/v1.32.1-standalone-strict/all.json'] =
        '/*.k8s.yaml',
      },
    },
  },
  on_init = function(client)
    client.server_capabilities.documentFormattingProvider = true
  end,
}