-- /qompassai/Diver/lsp/docker_ls.lua
-- Qompass AI Docker LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- pnpm add -g dockerfile-language-server-nodejs@latest
---@type vim.lsp.Config
return {
    cmd = { ---@type string[]
        'docker-langserver',
        '--stdio',
    },
    filetypes = { ---@type string[]
        'dockerfile',
    },
    root_markers = { ---@type string[]
        'Dockerfile',
        'docker-compose.yaml',
        'docker-compose.yml',
        'compose.yaml',
        'compose.yml',
        'docker-bake.json',
        'docker-bake.hcl',
        'docker-bake.override.json',
        'docker-bake.override.hcl',
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
