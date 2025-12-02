-- /qompassai/Diver/lsp/docker_composels.lua
-- Qompass AI Docker-Compose LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
-- Reference: https://github.com/microsoft/compose-language-service
-- pnpm add -g @microsoft/compose-language-service
vim.lsp.config['docker_compose_language_service'] = {
  cmd = {
    'docker-compose-langserver',
    '--stdio' },
  filetypes = {
    'yaml',
    'dockercompose'
  },
  root_markers = {
    'docker-compose.yml',
    'docker-compose.yaml',
    '.git'
  },
  settings = {
    dockerCompose = {
      enableCompletion = true,
      enableHover = true,
      validate = true,
      diagnostics = {
        enable = true,
        severity = 'info',
      },
    },
  },
  init_options = {
    dockerCompose = {
      fileExtensions = {
        '.yml',
        '.yaml'
      },
      serviceCompletion = true,
      imageCompletion = true,
      schemaStoreEnable = true,
      trace = {
        server = 'verbose'
      },
    },
  },
}