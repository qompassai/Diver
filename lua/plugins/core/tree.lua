-- /qompassai/Diver/lua/plugins/core/tree.lua
-- Qompass AI Treesitter plugin spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
return {
  {
    'nvim-treesitter/nvim-treesitter',
    config = function(_, opts)
		require('config.core.tree').tree_cfg(opts)
	end,
	},
}
