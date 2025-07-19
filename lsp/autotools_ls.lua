-- /qompassai/Diver/lsp/astro.lua
-- Qompass AI Astro-ls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
vim.lsp.config['autotools_ls'] = {
	cmd = { 'autotools-language-server' },
	filetypes = { 'config', 'automake', 'make' },
	root_markers = { 'configure.ac', 'Makefile', 'Makefile.am', '*.mk' }
}
