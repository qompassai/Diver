-- ~/.config/nvim/lua/plugins/nav/neotree.lua
-- ------------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return
{
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    {"3rd/image.nvim", opts = {}},
  },
  lazy = false,
  ---@module "neo-tree"
  ---@type neotree.Config?
  opts = {
  },
}
