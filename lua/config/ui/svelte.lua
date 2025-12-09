-- /qompassai/Diver/lua/config/ui/svelte.lua
-- Qompass AI Diver Svelte Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
local M = {}
function M.svelte_lsp(opts)
	opts.servers = opts.servers or {}
	opts.servers.svelte = {
		filetypes = { 'svelte' },
		settings = {
			svelte = {
				plugin = {
					typescript = {
						diagnostics = true,
						hover = true,
						completions = true,
						definitions = true,
						findReferences = true,
						codeActions = true,
					},
				},
			},
		},
	}
	return opts
end
function M.astro_lsp(opts)
	opts.servers = opts.servers or {}
	opts.servers.astro = { filetypes = { 'astro' } }

	return opts
end
function M.svelte_treesitter(opts)
	opts = opts or {}
	opts.ensure_installed = opts.ensure_installed or {}
	vim.list_extend(opts.ensure_installed, {})
	return opts
end
function M.svelte_conform(opts)
	opts.formatters_by_ft = opts.formatters_by_ft or {}
	opts.formatters_by_ft['svelte'] = { 'biome' }
	opts.formatters_by_ft['astro'] = { 'biome' }
	return opts
end
return M
