-- /qompassai/Diver/lua/plugins/lang/go.lua
-- Qompass AI Go Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@meta
return {
  {
    'ray-x/go.nvim',
    ft = { --[[@as string[] ]]
      'go',
      'gomod',
    },
    config = function() ---@type fun()
    end,
    dependencies = { --[[@as string[] ]]
      'ray-x/guihua.lua',
      'ray-x/navigator.lua',
    },
  },
}