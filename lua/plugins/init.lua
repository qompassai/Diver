-- #################################################################
-- /qompassai/lua/plugins/init.lua
-- Qompass AI Init
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################

-- /qompassai/Diver/lua/plugins/init.lua
-- Qompass AI Diver Plugins Init
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------
--[[
local function gh(repository)
return ('https://github.com/%s'):format(repository)
end
vim.pack.add({
							{
							src = 'https://github.com/OWNER/PLUGIN.nvim',
							name = 'PLUGIN.nvim',
							version = vim.version.range('^1.0.0'),
							data = {
							config = function() require('PLUGIN').setup({
								--Options
								--})
							end,
							},
						},
				},
		{
				confirm = true,
				load = function(plugin) vim.cmd.packadd(plugin.spec.name)
				if plugin.spec.data and plugin.spec.data.config
				then plugin.spec.data.config() end
						end,
				})
--]]
local api = vim.api
local add = vim.pack.add
local gh = function(x)
	return 'https://github.com/' .. x
end
--[[
local cb = function(x)
  return 'https://codeberg.org/' .. x
end
--]]
local update = vim.pack.update
local range = vim.version.range
local tree = require('config.core.tree')
local M = {}
vim.opt.packpath = vim.opt.runtimepath:get()
local function github(repo)
	return 'https://github.com/' .. repo
end
local plugin_setup = {}
local plugins = {
	{
		data = {
			config = function()
				require('blink.cmp').setup(require('config.lang.cmp').blink_cmp())
			end,
		},
		src = gh('Saghen/blink.cmp'),
		update = true,
		version = range('1.*'),
	},
	{
		src = gh('Saghen/blink.compat'),
		update = true,
		version = range('2.*'),
	},
	{
		src = gh('hrsh7th/cmp-nvim-lua'),
		update = true,
		version = 'main',
	},
	{
		src = gh('hrsh7th/cmp-buffer'),
	},
	{
		data = {
			config = function()
				require('config.core.tree').treesitter({})
			end,
		},
		src = gh('nvim-treesitter/nvim-treesitter'),
		update = true,
		version = 'main',
	},
	{
		src = gh('vhyrro/luarocks.nvim'),
		update = true,
		version = 'main',
	},
	{
		src = gh('folke/which-key.nvim'),
		update = true,
		version = 'main',
	},
	{
		src = gh('nvim-treesitter/nvim-treesitter-textobjects'),
		update = true,
		version = 'main',
	},
	{
		src = gh('L3MON4D3/LuaSnip'),
		update = true,
		version = range('2.*'),
	},
	{
		src = gh('rafamadriz/friendly-snippets'),
		update = true,
		version = 'main',
	},

	{
		src = gh('moyiz/blink-emoji.nvim'),
		version = 'master',
	},
	{
		src = gh('Kaiser-Yang/blink-cmp-dictionary'),
		update = true,
		version = range('2.*'),
	},
	{
		data = {
			config = function()
				require('config.ui.line').setup()
			end,
		},
		src = gh('nvim-lualine/lualine.nvim'),
		update = true,
		version = 'master',
	},
	{
		data = {
			priority = 1000,
		},
		src = gh('olimorris/onedarkpro.nvim'),
		update = true,
	},
	{
		src = gh('catppuccin/nvim'),
	},
	{
		src = gh('EdenEast/nightfox.nvim'),
	},
	{
		src = gh('folke/tokyonight.nvim'),
		name = 'tokyonight.nvim',
	},
	{
		src = gh('marko-cerovac/material.nvim'),
	},
	{
		src = gh('Mofiqul/dracula.nvim'),
	},
	{
		src = gh('navarasu/onedark.nvim'),
		name = 'onedark.nvim',
	},
	{
		src = gh('projekt0n/github-nvim-theme'),
		name = 'github-nvim-theme',
	},
	-- { src = gh('sainnhe/gruvbox-material'), name = 'gruvbox-material' },
	{
		src = gh('shaunsingh/nord.nvim'),
		name = 'nord.nvim',
	},
	{
		src = gh('vyfor/cord.nvim'),
		data = {
			event = 'BufEnter',
			config = function()
				local opts = {}
				require('config.ui.themes').cord_setup(opts)
			end,
		},
	},
	{
		src = github('folke/flash.nvim'),
		update = true,
		version = range('2.*'),
	},
}
--[[ 
plugin_setup[github('Saghen/blink.cmp')] = function()
local cmp_cfg = require('config.lang.cmp').blink_cmp()
require('blink.cmp').setup(cmp_cfg)
end
--]]
plugin_setup[github('nvim-treesitter/nvim-treesitter')] = function()
	tree.treesitter({})
end
plugin_setup[github('vhyrro/luarocks.nvim')] = function()
	local ok_cfg, lua_cfg = pcall(require, 'config.lang.lua')
	if not ok_cfg or type(lua_cfg.lua_luarocks) ~= 'function' then
		vim.notify('luarocks setup: config.lang.lua.lua_luarocks missing', vim.log.levels.WARN)
		return
	end
	local ok_opts, opts = pcall(lua_cfg.lua_luarocks, {})
	if not ok_opts then
		vim.notify('luarocks setup failed: ' .. tostring(opts), vim.log.levels.ERROR)
		return
	end
	local ok_lr, lr = pcall(require, 'luarocks-nvim')
	if not ok_lr or type(lr.setup) ~= 'function' then
		vim.notify('luarocks-nvim module missing or invalid', vim.log.levels.ERROR)
		return
	end

	lr.setup(opts)
end

plugin_setup[github('folke/which-key.nvim')] = function()
	require('config.core.whichkey')
end

plugin_setup[github('nvim-lualine/lualine.nvim')] = function()
	require('config.ui.line').setup()
end

plugin_setup[github('folke/flash.nvim')] = function()
	require('config.core.flash').flash_cfg()
end
--- @return boolean ok
--- @return string[] errors
function M.validate_specs()
	local errors = {}

	for i, spec in ipairs(plugins) do
		if type(spec) ~= 'table' then
			errors[#errors + 1] = ('plugins[%d] is not a table'):format(i)
		else
			if type(spec.src) ~= 'string' or spec.src == '' then
				errors[#errors + 1] = ('plugins[%d] is missing a valid src'):format(i)
			elseif not spec.src:match('^https://') then
				errors[#errors + 1] = ('plugins[%d].src is not a URL: %s'):format(i, spec.src)
			end

			if spec.version ~= nil and type(spec.version) ~= 'string' and type(spec.version) ~= 'table' then
				errors[#errors + 1] = ('plugins[%d].version has invalid type'):format(i)
			end
			if spec.update ~= nil and type(spec.update) ~= 'boolean' then
				errors[#errors + 1] = ('plugins[%d].update must be boolean'):format(i)
			end
		end
	end

	return #errors == 0, errors
end

--- @return table[]
function M.specs()
	return plugins
end

function M.setup_plugins()
	for _, spec in ipairs(plugins) do
		local setup = plugin_setup[spec.src]
		if type(setup) == 'function' then
			local ok, err = pcall(setup)
			if not ok then
				vim.schedule(function()
					vim.notify(
						'Plugin setup failed for ' .. spec.src .. ': ' .. tostring(err),
						vim.log.levels.ERROR,
						{ title = 'vim.pack' }
					)
				end)
			end
		end
	end
end

function M.bootstrap()
	local ok, errors = M.validate_specs()
	if not ok then
		for _, err in ipairs(errors) do
			vim.notify(err, vim.log.levels.ERROR, {
				title = 'vim.pack spec validation',
			})
		end
		return
	end

	add(plugins, {
		confirm = false,
		load = true,
	})

	M.setup_plugins()
end

api.nvim_create_user_command('PackUpdate', function()
	vim.notify('Opening plugin update confirmation buffer…', vim.log.levels.INFO)
	update()
	api.nvim_create_autocmd('BufWritePost', {
		pattern = '*',
		once = true,
		callback = function(ev)
			if ev.buf and vim.bo[ev.buf].buftype == 'acwrite' then
				vim.notify('Plugins updated successfully!', vim.log.levels.INFO)
			end
		end,
	})
end, {
	desc = 'Update all vim.pack plugins (interactive - :write to confirm)',
})
api.nvim_create_user_command('PackUpdateAuto', function()
	vim.notify('Updating plugins (auto-confirm)…', vim.log.levels.INFO)
	local ok, err = pcall(function()
		update(nil, { confirm = true })
	end)
	if ok then
		vim.notify('Plugins updated successfully!', vim.log.levels.INFO)
	else
		vim.notify('Plugin update failed: ' .. tostring(err), vim.log.levels.ERROR)
	end
end, {
	desc = 'Update all vim.pack plugins (auto-confirm, no interaction)',
})
api.nvim_create_user_command('PackAdd', function(opts)
	if opts.args == '' then
		vim.notify('Usage: :PackAdd <github-user>/<repo>', vim.log.levels.WARN)
		return
	end
	local repo = opts.args
	local spec = {
		src = github(repo),
		update = true,
	}
	if type(spec.src) ~= 'string' or spec.src == '' then
		vim.notify('PackAdd failed: invalid src for ' .. repo, vim.log.levels.ERROR)
		return
	end

	local ok, err = pcall(function()
		add({ spec }, {
			confirm = false,
			load = true,
		})
	end)
	if not ok then
		vim.notify('PackAdd failed: ' .. tostring(err), vim.log.levels.ERROR)
		return
	end
	vim.notify('Plugin added: ' .. repo, vim.log.levels.INFO)
end, {
	nargs = 1,
	desc = 'Add a new plugin from GitHub',
})
M.bootstrap()
require('plugins.data')
require('plugins.nav')
require('plugins.edu')
return M
