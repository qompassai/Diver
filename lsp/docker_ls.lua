-- /qompassai/Diver/lsp/docker_ls.lua
-- Qompass AI Docker LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
return ---@type vim.lsp.Config
{
    capabilities = require('config.core.lsp').capabilities,
    cmd = {
        'docker-langserver',
        '--stdio',
    },
    filetypes = {
        'dockerfile',
    },
    on_attach = require('config.core.lsp').on_attach,
    root_markers = {
        'compose.yaml',
        'compose.yml',
        'docker-bake.json',
        'docker-bake.hcl',
        'docker-bake.override.hcl',
        'docker-bake.override.json',
        'docker-compose.yaml',
        'docker-compose.yml',
        'Dockerfile',
    },
    settings = {
        docker = {
            languageserver = {
                formatter = {
                    ignoreMultilineInstructions = true,
                },
            },
        },
    },
}
