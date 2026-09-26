--- yaml-language-server language-server config — starts the YAML files tutor.
---
--- Plain-language version: a language server is a helper program that reads your code and tells Neovim about
--- errors, completions, and definitions -- like a tutor looking over your shoulder. This file is the introduction
--- card that tells Neovim how to start the `yaml-language-server` tutor whenever you open YAML files. It only takes
--- effect if `yaml-language-server` is installed on your computer.
---@module 'lsp.yaml_ls'
-- /qompassai/Diver/lsp/yaml_ls.lua
-- Qompass AI Yaml LSP Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- Schema URLs live in locals so the long keys stay within the line limit.
local k8s_schema = 'https://raw.githubusercontent.com/yannh/kubernetes-json-schema/refs/heads/master/'
    .. 'v1.32.1-standalone-strict/all.json'

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
            [k8s_schema] = 'helm/values*.yaml',
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
