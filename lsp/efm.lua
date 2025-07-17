-- efm.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
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
