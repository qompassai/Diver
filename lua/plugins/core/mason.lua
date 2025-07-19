-- /qompassai/Diver/lua/plugins/core/mason.lua
-- Qompass AI Diver Mason Setup
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------------
local mason_cfg = require('config.core.mason')
return {
	{
		'mason-org/mason.nvim',
		event = 'VeryLazy',
		build = ":MasonUpdate",
		cmd = { "Mason", "MasonInstall", "MasonUninstall" },
		config = function(_, opts)
			mason_cfg.mason_setup(opts)
		end,
	},
	{
		'mason-org/mason-lspconfig.nvim',
		event = 'VeryLazy',
		dependencies = { 'mason-org/mason.nvim' },
		config = function(_, opts)
			mason_cfg.mason_lspconfig(opts)
		end,
	},
	{
		'WhoIsSethDaniel/mason-tool-installer.nvim',
		event = 'VeryLazy',
		config = function(_, opts)
			mason_cfg.mason_tools(opts)
		end,
	},
	{
		'jay-babu/mason-nvim-dap.nvim',
		event = 'VeryLazy',
		dependencies = { 'mfussenegger/nvim-dap', 'williamboman/mason.nvim', 'rcarriga/nvim-dap-ui', 'igorlfs/nvim-dap-view' },
		config = function(_, opts)
			mason_cfg.mason_dap(opts)
		end,
	}
}
