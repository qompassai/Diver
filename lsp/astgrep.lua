-- /qompassai/Diver/lsp/astgrep.lua
-- Qompass AI Astgrep LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['ast-grep'] = {
	cmd = { 'ast-grep', 'lsp' },
	workspace_required = true,
	reuse_client = function(client, config)
		config.cmd_cwd = config.root_dir
		return client.config.cmd_cwd == config.cmd_cwd
	end,
	filetypes = { -- https://ast-grep.github.io/reference/languages.html
		'c',
		'cpp',
		'rust',
		'go',
		'java',
		'python',
		'javascript',
		'javascriptreact',
		'javascript.jsx',
		'typescript',
		'typescriptreact',
		'typescript.tsx',
		'html',
		'css',
		'kotlin',
		'dart',
		'lua',
	},
	root_markers = { 'sgconfig.yaml', 'sgconfig.yml' },
}
