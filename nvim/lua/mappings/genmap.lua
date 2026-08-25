-- /qompassai/Diver/lua/mappings/genmap.lua
-- Qompass AI Diver General Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.genmap'
local M = {}
---@param lhs string
---@param visible_key string
---@param fallback_key string
---@param desc string
local function command_line_completion_map(lhs, visible_key, fallback_key, desc)
	vim.keymap.set('c', lhs, function()
		if vim.fn.pumvisible() == 1 then
			return visible_key
		end
		return fallback_key
	end, {
		desc = desc,
		expr = true,
		silent = true,
	})
end

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

function M.setup_genmap()
	if M.configured then
		return
	end
	M.configured = true

	command_line_completion_map('<C-j>', '<C-n>', '<C-j>', 'Command line: next completion item')
	command_line_completion_map('<C-k>', '<C-p>', '<C-k>', 'Command line: previous completion item')
	command_line_completion_map('<Down>', '<C-n>', '<Down>', 'Command line: next completion item')
	command_line_completion_map('<Up>', '<C-p>', '<Up>', 'Command line: previous completion item')

	map('n', '<leader>U', function()
		vim.pack.update(nil, { force = true })
	end, 'Packages: force update vim.pack plugins')
	map('i', '<A-b>', '<Esc>^i', 'Insert: move to beginning of line')
	map('i', '<A-e>', '<End>', 'Insert: move to end of line')
	map('i', '<A-h>', '<Left>', 'Insert: move left')
	map('i', '<A-j>', '<Down>', 'Insert: move down')
	map('i', '<A-k>', '<Up>', 'Insert: move up')
	map('i', '<A-l>', '<Right>', 'Insert: move right')
	map('n', '<C-h>', '<C-w>h', 'Window: move left')
	map('n', '<C-j>', '<C-w>j', 'Window: move down')
	map('n', '<C-k>', '<C-w>k', 'Window: move up')
	map('n', '<C-l>', '<C-w>l', 'Window: move right')
	map('n', '<C-s>', '<cmd>write<cr>', 'File: save')
	map('n', '<leader>ya', '<cmd>%yank +<cr>', 'File: copy entire buffer to clipboard')
	map('n', '<leader>nh', '<cmd>nohlsearch<cr>', 'Search: clear highlights')
end

return M
