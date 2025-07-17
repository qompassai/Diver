-- /qompassai/Diver/lsp/postgres_lsp.lua
-- Qompass AI PostGres LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
	cmd = { 'postgrestools', 'lsp-proxy' },
	filetypes = {
		'sql',
	},
	root_markers = { 'postgrestools.jsonc' },
}
