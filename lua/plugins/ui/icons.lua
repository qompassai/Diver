-- /qompassai/Diver/lua/plugins/ui/icons.lua
-- Qompass AI Icons Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local icons_cfg = require('config.ui.icons')
return  {
  {
    "nvim-tree/nvim-web-devicons",
    config = icons_cfg.icons_dev,
  },
  {
    "yamatsum/nvim-nonicons",
    config = icons_cfg.icons_nonicons,
  },
  {
    "zakissimo/smoji.nvim",
    branch       = "main",
    dependencies = { "stevearc/dressing.nvim" },
    config       = icons_cfg.icons_smoji,
  },
}
