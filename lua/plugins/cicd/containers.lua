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
    'docker-compose.yml',
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    'mgierada/lazydocker.nvim',
  },
  cmd = {
    'ContainerList',
    'ContainerLogs',
    'ContainerExec',
    'ContainerStart',
    'ContainerStop',
    'ContainerKill',
    'ContainerInspect',
    'ContainerRemove',
    'ContainerPrune',
    'ImageList',
    'ImagePull',
    'ImageRemove',
    'ImagePrune',
  },
  config = function()
    extra_schemas = {
    }
  end,
}