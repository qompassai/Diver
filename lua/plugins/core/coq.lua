-- /qompassai/Diver/lua/plugins/core/coq.lua
-- Qompass AI Conquer of Completion (Coq) Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
---@module 'plugins.cmp.coq'
return {
  {
    'ms-jpq/coq_nvim',
    version = '*',
    dependencies = { ---@type table[]
      {
        'ms-jpq/coq.artifacts',
        branch = 'artifacts'
      },
      {
        'ms-jpq/coq.thirdparty',
        branch = '3p'
      },
    },
    init = function() ---@return nil
      vim.g.coq_settings = {
        auto_start = false,
      }
    end,
    config = function() end, ---@return nil
  },
}