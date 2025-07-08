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
  },
}
