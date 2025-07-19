-- ts_query_ls.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config('ts_query_ls', {
	cmd = { 'ts_query_ls' },
	filetypes = { 'query' },
	root_markers = { 'queries', '.git' },
	settings = {
		parser_aliases = {
			ecma = 'javascript',
			jsx = 'javascript',
			php_only = 'php',
			language_retrieval_patterns = {
				'languages/src/([^/]+)/[^/]+\\.scm$',
			},
			parser_install_directories = {
				vim.fs.joinpath(
					vim.fn.stdpath('data'),
					'/lazy/nvim-treesitter/parser/'
				),
			},
		},
	}
})
