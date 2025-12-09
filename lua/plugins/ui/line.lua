-- /qompassai/Diver/lua/plugins/ui/line.lua
-- Qompass AI Illum Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
return {
	{
		'nvim-lualine/lualine.nvim',
		event = 'VeryLazy',
		dependencies = {
			'nvim-tree/nvim-web-devicons',
			{ 'echasnovski/mini.icons', version = '*' },
			'echasnovski/mini.pick',
			'nvim-treesitter/nvim-treesitter',
			'MeanderingProgrammer/render-markdown.nvim',
			'vhyrro/luarocks.nvim',
			'folke/tokyonight.nvim',
			'ibhagwan/fzf-lua'
		},
		config = function()
			require('config.ui.line')
		end
	}
}
