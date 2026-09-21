-- /qompassai/Diver/lsp/docker_ls.lua
-- Qompass AI Docker LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ---------------------------------------------------
---@source https://github.com/docker/docker-language-server
--- go install github.com/docker/docker-language-server/cmd/docker-language-server@latest

return ---@type vim.lsp.Config
{
  cmd = {
    'docker-langserver',
    'start',
    '--stdio',
  },
  filetypes = {
    'dockerfile',
  },
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
    dockercomposeExperimental = {
      composeSupport = true,
    },
    dockerfileExperimental = {
      removeOverlappingIssues = false,
    },
    telemetry = 'off',

    docker = {
      languageserver = {
        formatter = {
          ignoreMultilineInstructions = true,
        },
      },
    },
  },
}
