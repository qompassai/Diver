-- /qompassai/diver/lua/plugins/ui/css.lua
-- Qompass AI CSS Plugin spec
-- Copyright (c) 2025 Qompass AI, All Rights Reserved
-----------------------------------------------------
local css_cfg = require('config.ui.css')
return {
	{
		'windwp/nvim-autopairs',
		event = 'InsertEnter',
		config = true,
	},
	{
		"luckasRanarison/tailwind-tools.nvim",
		name = "tailwind-tools",
		build = ":UpdateRemotePlugins",
		dependencies = {
		--	"nvim-treesitter/nvim-treesitter",
			"ibhagwan/fzf-lua",
		},
		config = function(_, opts)
			css_cfg = require('config.ui.css')
			css_cfg.css_tools(opts)
		end,
	},
	{
		'nvchad/nvim-colorizer.lua',
		event = 'BufReadPre',
		config = function(_, opts)
			css_cfg.css_colorizer(opts)
		end,
	},
}
