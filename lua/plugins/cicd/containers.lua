-- /qompassai/Diver/lua/plugins/cicd/containers.lua
-- Qompass AI Diver Containers Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
  'dgrbrady/nvim-docker',
  ft = {
    'dockerfile',
    'containerfile',
    'docker-compose.yaml',
    'docker-compose.yml'
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'nvimtools/none-ls.nvim',
    'mgierada/lazydocker.nvim',
    'b0o/schemastore.nvim'
  },
  cmd = {
    'ContainerList',
    'ContainerLogs', 'ContainerExec', 'ContainerStart',
    'ContainerStop', 'ContainerKill', 'ContainerInspect', 'ContainerRemove',
    'ContainerPrune', 'ImageList', 'ImagePull', 'ImageRemove', 'ImagePrune'
  },
  config = function()
    extra_schemas = {
      {
        fileMatch = {
          'docker-compose*.yml',
          'docker-compose*.yaml'
        },
        url = 'https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json'
      }
    }
  end
}