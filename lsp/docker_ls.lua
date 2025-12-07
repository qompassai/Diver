-- /qompassai/Diver/lsp/docker_ls.lua
-- Qompass AI Docker LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- pnpm add -g dockerfile-language-server-nodejs
vim.lsp.config['docker_ls'] = {
  cmd = {
    'docker-langserver',
    '--stdio'
  },
  filetypes = {
    "dockerfile"
  },
  root_markers = {
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