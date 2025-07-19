-- /qompassai/Diver/lsp/ansiblels.lua
-- Qompass AI Ansiblels LSP Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
vim.lsp.config['ansiblels'] = {
	cmd = { 'ansible-language-server', '--stdio' },
	settings = {
		ansible = {
			python = {
				interpreterPath = 'python',
			},
			ansible = {
				path = 'ansible',
			},
			executionEnvironment = {
				enabled = true,
			},
			validation = {
				enabled = true,
				lint = {
					enabled = true,
					path = 'ansible-lint',
				},
			},
		},
	},
	filetypes = { 'yaml.ansible' },
	root_markers = { 'ansible.cfg', '.ansible-lint' },
}
