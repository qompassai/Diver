-- dprint.lua
-- Qompass AI - [Add description here]
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local util = require 'lspconfig.util'

vim.lsp.config['dprint'] = {
	cmd = { 'dprint', 'lsp' },
	filetypes = {
		'javascript',
		'javascriptreact',
		'typescript',
		'typescriptreact',
		'json',
		'jsonc',
		'markdown',
		'python',
		'toml',
		'rust',
		'roslyn',
		'graphql',
	},
	root_dir = util.root_pattern('dprint.json', '.dprint.json', 'dprint.jsonc', '.dprint.jsonc'),
	single_file_support = true,
	settings = {},
}
