-- /qompassai/Diver/lua/mappings/cicdmap.lua
-- Qompass AI Diver CICD Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.cicdmap'
local M = {}
local terminals = {}
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
local function map(mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, {
		desc = desc,
		silent = true,
	})
end
---@param direction 'horizontal'|'vertical'|'float'
local function toggle_terminal(direction)
	local ok, terminal_module = pcall(require, 'toggleterm.terminal')
	if not ok or type(terminal_module.Terminal) ~= 'table' then
		vim.notify('toggleterm.nvim is unavailable', vim.log.levels.ERROR, {
			title = 'Terminal mappings',
		})
		return
	end
	if not terminals[direction] then
		terminals[direction] = terminal_module.Terminal:new({
			direction = direction,
			hidden = true,
		})
	end
	terminals[direction]:toggle()
end
local function zoxide_picker()
	local ok, telescope = pcall(require, 'telescope')
	if not ok or not telescope.extensions or not telescope.extensions.zoxide then
		vim.notify('The Telescope zoxide extension is unavailable', vim.log.levels.ERROR, {
			title = 'Zoxide mappings',
		})
		return
	end
	telescope.extensions.zoxide.list()
end

local function zoxide_add_cwd()
	if vim.fn.executable('zoxide') ~= 1 then
		vim.notify('zoxide is not available in PATH', vim.log.levels.ERROR, {
			title = 'Zoxide mappings',
		})
		return
	end

	local cwd = vim.uv.cwd() or vim.fn.getcwd()
	vim.system({
		'zoxide',
		'add',
		cwd,
	}, {
		text = true,
	}, function(result)
		vim.schedule(function()
			if result.code == 0 then
				vim.notify(('Added %s to zoxide'):format(cwd), vim.log.levels.INFO, {
					title = 'Zoxide mappings',
				})
				return
			end
			local message = result.stderr ~= '' and result.stderr or 'zoxide add failed'
			vim.notify(vim.trim(message), vim.log.levels.ERROR, {
				title = 'Zoxide mappings',
			})
		end)
	end)
end
function M.setup_cicdmap()
	if M.configured then
		return
	end
	M.configured = true
	map('n', '<leader>h', function()
		toggle_terminal('horizontal')
	end, 'Terminal: toggle horizontal')
	map('n', '<leader>v', function()
		toggle_terminal('vertical')
	end, 'Terminal: toggle vertical')
	map({ 'n', 't' }, '<A-h>', function()
		toggle_terminal('horizontal')
	end, 'Terminal: toggle horizontal')
	map({ 'n', 't' }, '<A-v>', function()
		toggle_terminal('vertical')
	end, 'Terminal: toggle vertical')
	map({ 'n', 't' }, '<A-i>', function()
		toggle_terminal('float')
	end, 'Terminal: toggle floating')

	map('n', '<leader>zi', '<cmd>Zi<cr>', 'Zoxide: interactive global directory')
	map('n', '<leader>zq', ':Z ', 'Zoxide: query global directory')
	map('n', '<leader>zf', zoxide_picker, 'Zoxide: open Telescope picker')
	map('n', '<leader>zlq', ':Lz ', 'Zoxide: query window-local directory')
	map('n', '<leader>ztq', ':Tz ', 'Zoxide: query tab-local directory')
	map('n', '<leader>zli', '<cmd>Lzi<cr>', 'Zoxide: interactive window-local directory')
	map('n', '<leader>zti', '<cmd>Tzi<cr>', 'Zoxide: interactive tab-local directory')
	map('n', '<leader>za', zoxide_add_cwd, 'Zoxide: add current directory')
end

return M
