-- /qompassai/Diver/lua/plugins/ui/html.lua
-- Qompass AI HTML Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local html_cfg = require('config.ui.html')
return {
    {
        'windwp/nvim-ts-autotag',
		event = 'VeryLazy',
		dependencies = {
			'ibhagwan/fzf-lua'},
			config = function(_, opts)
				html_cfg.html_cfg(opts)
			end,
            }
        }
