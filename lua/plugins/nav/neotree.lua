-- ~/.config/nvim/lua/plugins/nav/neotree.lua
-- ------------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return
{
  "nvim-neo-tree/neo-tree.nvim",
	event = 'VimEnter',
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
    {"3rd/image.nvim", opts = {}},
  },
	config = function(_, opts)
		require('config.nav.neotree').neotree_cfg(opts)
	end,
}
