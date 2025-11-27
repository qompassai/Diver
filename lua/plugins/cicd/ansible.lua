-- qompassai/Diver/lua/plugins/cicd/ansible.lua
-- Qompass AI Diver Ansible Plugin Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
return {
	"pearofducks/ansible-vim",
	ft = { 'yaml.ansible', 'ansible' },
	dependencies = {
		'b0o/schemastore.nvim',
	},
	config = function(_, opts)
		require('config.cicd.ansible').ansible_cfg(opts)
	end,
}
