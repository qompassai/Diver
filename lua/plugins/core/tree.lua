-- /qompassai/Diver/lua/plugins/core/tree.lua
-- Qompass AI Treesitter plugin spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
local tree_cfg = require('config.core.tree')
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    lazy   = false,
    config = tree_cfg.treesitter,
  }, {
    'nvim-neo-tree/neo-tree.nvim',
    event = 'BufEnter',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
      '3rd/image.nvim'
    },
    opts = function()
      return tree_cfg.neotree
    end,
  },
}
