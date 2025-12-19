-- /qompassai/Diver/lua/plugins/core/neotest.lua
-- Qompass AI Diver NeoTest Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
---@meta
---@module 'plugins.cmp.neotest'
return {
  'nvim-neotest/neotest',
  dependencies = { ---@type table
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'nvim-neotest/neotest-plenary',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    'ibhagwan/fzf-lua',
  },
  opts = {
    adapters = { ---@type string[]
      'neotest-plenary',
    },
  },
}