-- /qompassai/Diver/lsp/yaml_ls.lua
-- Qompass AI Yaml LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
  cmd = {
    'yaml-language-server',
    '--stdio',
  },
  filetypes = {
    'yaml',
    'yaml.docker-compose',
    'yaml.gitlab',
    'yaml.helm-values',
    'yml',
  },
  root_markers = {
    '.git',
  },
  settings = {
    yaml = {
      completion = true,
      customTags = {
        '!Ref scalar',
        '!Sub scalar',
        '!FindInMap sequence:string',
      },
      disableDefaultProperties = true,
      disableSchemaDetection = {},
      format = {
        bracketSpacing = true,
        enable = true,
        proseWrap = 'preserve',
        printWidth = 80,
        singleQuote = true,
      },
      hover = true,
      hoverSchemaSource = true,
      http = {
        proxy = nil,
        proxyStrictSSL = false,
      },
      keyOrdering = false,
    },
    kubernetesVersion = '1.32.1',
    kubernetesCRDStore = {
      enable = true,
      -- url = ''
    },
    maxItemsComputed = 5000,
    redhat = {
      telemetry = {
        enabled = false,
      },
    },
    schemas = {
      ['https://json.schemastore.org/github-workflow.json'] = '/.github/workflows/*',
      kubernetes = {
        '/*.k8s.yaml',
        '/*.k8s.yml',
        'k8s/**/*.yaml',
        'k8s/**/*.yml',
      },
      ['https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/v1.32.1-standalone-strict/all.json'] = 'helm/values*.yaml',
      ['https://www.schemastore.org/json/f-droid-data-metadata.json'] = 'metadata/*.yml',
    },
    schemaStore = {
      enable = true,
      url = 'https://www.schemastore.org/api/json/catalog.json',
    },
    style = {
      flowMapping = 'forbid',
      flowSequence = 'forbid',
    },
    suggest = {
      parentSkeletonSelectedFirst = false,
    },
    validate = true,
    yamlVersion = '1.2',
  },
}
