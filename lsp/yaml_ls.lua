-- /qompassai/Diver/lsp/yaml_ls.lua
-- Qompass AI Yaml LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = capabilities,
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
            redhat = {
                telemetry = {
                    enabled = false,
                },
            },
            completion = true,
            hover = true,
            validate = true,
            yamlVersion = '1.2',
            format = {
                enable = true,
                bracketSpacing = true,
                proseWrap = 'preserve',
                printWidth = 80,
                singleQuote = true,
            },

            schemaStore = {
                enable = true,
                url = 'https://www.schemastore.org/api/json/catalog.json',
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
            },
            maxItemsComputed = 5000,
            disableDefaultProperties = false,
            suggest = {
                parentSkeletonSelectedFirst = false,
            },
            style = {
                flowMapping = 'forbid',
                flowSequence = 'forbid',
            },
            keyOrdering = true,
        },
        http = {
            proxy = nil,
            proxyStrictSSL = false,
        },
    },
}