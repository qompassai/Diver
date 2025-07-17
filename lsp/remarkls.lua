local util = require 'lspconfig.util'
vim.lsp.config['remark_ls'] = {
	cmd = { 'remark-language-server', '--stdio' },
	filetypes = { 'markdown' },
	handlers = {
		["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" }),
		["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
	},
	root_dir = util.root_pattern(
		'.remarkrc',
		'.remarkrc.json',
		'.remarkrc.js',
		'.remarkrc.cjs',
		'.remarkrc.mjs',
		'.remarkrc.yml',
		'.remarkrc.yaml',
		'.remarkignore'
	),
	single_file_support = true,
}
