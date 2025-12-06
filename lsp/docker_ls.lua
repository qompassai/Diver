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
    "Dockerfile"
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