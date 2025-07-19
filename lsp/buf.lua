-- /qompassai/Diver/lsp/buf_ls.lua
-- Qompass AI Buf_ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

return {
	default_config = {
		cmd = { 'buf', 'beta', 'lsp', '--timeout=0', '--log-format=text' },
		filetypes = { 'proto' },
		root_dir = require('lspconfig.util').root_pattern('buf.yaml', '.git'),
	},
}
