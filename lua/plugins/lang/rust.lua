-- /qompassai/Diver/lua/plugins/lang/rust.lua
-- Qompass AI Diver Rust Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local rust_cfg = require('config.lang.rust')
return {
	{
		'mrcjkb/rustaceanvim',
		ft = { 'rust' },
		version = '^6',
		init = function()
			vim.g.rustaceanvim = rust_cfg.rust_rustacean()
		end,
		config = function(_, opts)
			rust_cfg = require('config.lang.rust')
			rust_cfg.nls(opts)
			vim.lsp.set_log_level('INFO')
			rust_cfg.rust_dap()
			rust_cfg.rust_crates()
			rust_cfg.rust_cfg()
		end,
		dependencies = {
			'nvim-lua/plenary.nvim', 'nvim-treesitter/nvim-treesitter',
			{
				'L3MON4D3/LuaSnip',
				dependencies = { 'rafamadriz/friendly-snippets' }
			},
		}
	},
	{
		'saecki/crates.nvim',
		event = { 'BufRead Cargo.toml' },
		config = function()
			rust_cfg.rust_crates()
		end,
	}
}
