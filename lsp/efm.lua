-- /qompassai/Diver/lsp/efm.lua
-- Qompass AI EFM LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['efm-langserver'] = {
	default_config = {
		cmd = { 'efm-langserver' },
		filetypes = {
			'cpp'
		},
		root_dir = function(fname)
			return vim.fs.dirname(vim.fs.find('.git', { path = fname, upward = true })[1])
		end,
		single_file_support = true,
	},
}
