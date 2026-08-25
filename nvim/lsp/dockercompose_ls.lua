-- /qompassai/Diver/lsp/docker_composels.lua
-- Qompass AI Docker-Compose LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/microsoft/compose-language-service
---@type vim.lsp.Config
return {
    cmd = {
        'docker-compose-langserver',
        '--stdio',
    },
    filetypes = {
        'yaml.docker-compose',
    },
    root_markers = {
        'compose.yaml',
        'compose.yml',
        'docker-compose.yaml',
        'docker-compose.yml',
    },
}
