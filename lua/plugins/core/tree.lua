-- /qompassai/Diver/lua/plugins/core/tree.lua
-- Qompass AI Treesitter plugin spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
	{
		'nvim-treesitter/nvim-treesitter',
		dependencies = {
			'nvim-neo-tree/neo-tree.nvim',
			'OXY2DEV/markview.nvim'
		},
		branch = 'master',
		lazy = false,
		build = ":TSUpdate",
		config = function(_, opts)
			require('config.core.tree').tree_cfg(opts)
		end,
	},
}
