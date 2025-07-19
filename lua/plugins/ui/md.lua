-- /qompassai/Diver/lua/plugins/ui/md.lua
-- Qompass AI Markdown Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

return {
	{
		'3rd/diagram.nvim',
		ft = 'markdown',
		dependencies = { '3rd/image.nvim', 'vhyrro/luarocks.nvim', 'nvim-treesitter/nvim-treesitter' },
		config = function(_, opts)
			require('config.ui.md').md_diagram(opts)
		end,
	},
	{
		'3rd/image.nvim',
		ft = 'markdown',
		dependencies = { 'vhyrro/luarocks.nvim', 'nvim-treesitter/nvim-treesitter' },
		config = function(_, opts)
			require('config.ui.md').md_image(opts)
		end,
	},
	{
		'brianhuster/live-preview.nvim',
		ft           = { 'markdown', 'html', 'asciidoc' },
		cmd          = { 'LivePreview' },
		dependencies = { 'ibhagwan/fzf-lua', 'vhyrro/luarocks.nvim' },
		config       = function(_, opts)
			require('config.ui.md').md_livepreview(opts)
		end,
	},
	{
		'OXY2DEV/markview.nvim',
		event = 'VeryLazy',
		ft = { 'markdown', 'mdx', 'smd' },
	},
	{
		'arminveres/md-pdf.nvim',
		dependencies = { '3rd/diagram.nvim', '3rd/image.nvim' },
		config = function(_, opts)
			require('config.ui.md').md_pdf(opts)
		end,
	},
	{
		'MeanderingProgrammer/render-markdown.nvim',
		ft = { 'markdown', 'mdx' },
		dependencies = {
			'nvim-treesitter/nvim-treesitter',
			'nvim-tree/nvim-web-devicons',
			'vhyrro/luarocks.nvim',
		},
		config = function(_, opts)
			require('config.ui.md').md_rendermd(opts)
		end,
	},
}
