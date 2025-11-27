-- /qompassai/lua/plugins/core/none-ls.lua
-- Qompass AI None-LS Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- -------------------------------------------
return {
	{
		'jay-babu/mason-null-ls.nvim',
		dependencies = {
			'nvimtools/none-ls.nvim',
			'zeioth/none-ls-autoload.nvim',
			'mason-org/mason.nvim',
			'williamboman/mason.nvim',
			'nvimtools/none-ls-extras.nvim',
			'gbprod/none-ls-shellcheck.nvim',
			'gbprod/none-ls-luacheck.nvim',
			'gbprod/none-ls-php.nvim',
			'gbprod/none-ls-ecs.nvim',
		},
		config = function(_, opts)
			require('config.core.none-ls').nls_cfg(opts)
		end,
	}
}
