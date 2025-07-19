-- /qompassai/Diver/lsp/remark_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['remark_ls'] = {
	cmd = { 'remark-language-server', '--stdio' },
	filetypes = { 'markdown' },
	root_markers = {
		'.remarkrc',
		'.remarkrc.json',
		'.remarkrc.js',
		'.remarkrc.cjs',
		'.remarkrc.mjs',
		'.remarkrc.yml',
		'.remarkrc.yaml',
		'.remarkignore',
	},
	single_file_support = true,
}
