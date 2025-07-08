-- /qompassai/Diver/lua/plugins/nav/neotree.lua
-- Qompass AI Diver Neo-tree plugin spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
-- /qompassai/Diver/lua/plugins/nav/neotree.lua
local cfg = require("config.nav.neotree")

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    event  = "BufEnter",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      "3rd/image.nvim",
      {
        "s1n7ax/nvim-window-picker",
        version = "2.*",
        config  = function()
          require("window-picker").setup({
            filter_rules = {
              include_current_win = false,
              autoselect_one      = true,
              bo = {
                filetype = { "neo-tree", "neo-tree-popup", "notify" },
                buftype  = { "terminal", "quickfix" },
              },
            },
          })
        end,
      },
    },
    opts = cfg.neotree_cfg({}),
  },
}
