-- /qompassai/Diver/lsp/bufls.lua
-- Qompass AI Bufls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------


local util = require 'lspconfig.util'

return {
	default_config = {
		cmd = { 'bufls', 'serve' },
		filetypes = { 'proto' },
		root_dir = function(fname)
			return util.root_pattern('buf.work.yaml', '.git')(fname)
		end,
	},
}
