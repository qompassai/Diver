-- Qompass AI Diver Zig Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local zig_cfg = require('config.lang.zig')
return {
	{
		'ziglang/zig.vim',
		ft = { 'zig', 'zon', 'zine' },
		config = function()
			zig_cfg = require('config.lang.zig')
			zig_cfg.zig_vim()
		end,
	},
	{
		'jinzhongjia/zig-lamp',
		ft = { 'zig', 'zon', 'zine' },
		dependencies = {
			'nvim-lua/plenary.nvim',
		},
		config = function()
			zig_cfg.zig_lamp()
		end,
	},
}
