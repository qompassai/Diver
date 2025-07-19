-- /qompassai/Diver/lsp/nil_ls.lua
-- Qompass AI Nix LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
	autostart = true,
	cmd = {
		'nil'
	},
	filetypes = {
		'nix'
	},
	root_markers = { 'flake.nix', '.git' },
	settings = {
		['nil'] = {
			testSetting = 42,
		},
	}
}
