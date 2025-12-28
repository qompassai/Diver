-- /qompassai/Diver/lua/plugins/lang/ts.lua
-- Qompass AI Diver Typescript Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'plugins.lang.ts'
return {
  {
    'pmizio/typescript-tools.nvim',
    ft = {
      'typescript',
      'typescriptreact',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    opts = {},
  },
}