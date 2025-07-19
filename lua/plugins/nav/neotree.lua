-- ~/.config/nvim/lua/plugins/nav/neotree.lua
-- ------------------------------------------
-- Copyright (C) 2025 Qompass AI, All rights reserved
return
{
  'nvim-neo-tree/neo-tree.nvim',
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    'MunifTanjim/nui.nvim',
			'vhyrro/luarocks.nvim',
    {"3rd/image.nvim", opts = {
				build = true,
			}},
  },
	config = function(_, opts)
		require('config.nav.neotree').neotree_cfg(opts)
	end,
}
