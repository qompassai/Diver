-- /qompassai/Diver/lua/plugins/ui/md.lua
-- Qompass AI Markdown Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------

return {
	{
		'3rd/diagram.nvim',
		dependencies = { "3rd/image.nvim" },
		config = function(_, opts)
			require('config.ui.md').md_diagram(opts)
		end,
	},
	{
		'3rd/image.nvim',
		config = function(_, opts)
			require('config.ui.md').md_image(opts)
		end,
	},
	{
		'brianhuster/live-preview.nvim',
		ft           = { 'markdown', "html", "asciidoc" },
		cmd          = { "LivePreview" },
		dependencies = { "ibhagwan/fzf-lua" },
		config       = function(_, opts)
			require('config.ui.md').md_livepreview(opts)
		end,
	},
	{
		'arminveres/md-pdf.nvim',
ft = {'markdown', 'mdx'},
		dependencies = { '3rd/diagram.nvim' },
		config = function(_, opts)
			require('config.ui.md').md_pdf(opts)
		end,
	},
	{
		'MeanderingProgrammer/render-markdown.nvim',
		ft = {'markdown', 'mdx'},
		dependencies = {
			'nvim-treesitter/nvim-treesitter',
			'echasnovski/mini.nvim',
		},
		config = function(_, opts)
			require('config.ui.md').md_rendermd(opts)
		end,
	},
}
