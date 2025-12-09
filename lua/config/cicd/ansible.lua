-- qompassai/Diver/lua/config/cicd/ansible.lua
-- Qompass AI Diver CICD Ansible Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.ansible_conform(opts)
	opts = opts or {}
	local conform_cfg = require("config.lang.conform")
	return {
		formatters_by_ft = {
			ansible = { 'ansible_lint' },
			yaml = { 'biome' },
			yml = { 'biome' },
			["yaml.ansible"] = { 'ansible_lint' }
		},
		format_on_save = conform_cfg.format_on_save,
		format_after_save = conform_cfg.format_after_save,
		default_format_opts = conform_cfg.default_format_opts,
	}
end

function M.nls()
	local nlsb = require('null-ls').builtins
	local sources = {
		nlsb.diagnostics.ansiblelint,
		nlsb.diagnostics.yamllint.with({
			ft = { 'yaml', 'yml' },
			cmd = 'yamllint'
		}),
		nlsb.code_actions.statix.with({
			ft = { 'yaml.ansible', 'ansible' }
		}),
	}
	return sources
end

function M.ansible_filetype_autocmd()
	vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
		pattern = {
			'*/playbooks/*.yml', '*/roles/*.yml', '*/inventory/*.yml',
			'*/host_vars/*.yml', '*/group_vars/*.yml'
		},
		callback = function() vim.bo.filetype = 'yaml.ansible' end
	})
end

---@param opts? { on_attach?: fun(client,bufnr), capabilities?: table }
function M.ansible_cfg(opts)
	opts = opts or {}
	M.ansible_filetype_autocmd()
	return {
		conform = M.ansible_conform(opts),
		nls     = M.nls(),
	}
end

return M
