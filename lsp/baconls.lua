-- /qompassai/Diver/lsp/baconls.lua
-- Qompass AI Baconls LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------

vim.lsp.config['bacon_ls'] = {
	cmd = { 'bacon-ls' },
	filetypes = { 'rust' },
	handlers = {
		['textDocument/hover'] = vim.lsp.with(vim.lsp.handlers.hover, { border = 'rounded' }),
		["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" }),
	},
	init_options = {
		init_options = {
			locationsFile = ".bacon-locations",
			updateOnSave = true,
			updateOnSaveWaitMillis = 1000,
			updateOnChange = true,
			validateBaconPreferences = true,
			createBaconPreferencesFile = true,
			runBaconInBackground = true,
			runBaconInBackgroundCommandArguments = "--headless -j bacon-ls",
			synchronizeAllOpenFilesWaitMillis = 2000,
		}
	},
	root_markers = {
		'.bacon-locations',
		'Cargo.toml'
	}
}
