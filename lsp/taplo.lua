-- taplo.lua
-- Qompass AI Taplo LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
	cmd = { 'taplo', 'lsp', 'stdio' },
	filetypes = { 'toml' },
	root_markers = { '.taplo.toml', 'taplo.toml', '.git' },
}
