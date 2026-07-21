-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
-- /qompassai/Diver/lua/utils/init.lua
-- Qompass AI Diver Utils
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {} ---@version JIT

local function safe_require(module)
	local ok, result = pcall(require, module)
	if not ok then
		vim.notify('Failed to load ' .. module .. ': ' .. tostring(result), vim.log.levels.WARN)
		return nil
	end
	return result
end
M.blue = require('utils.blue')
M.bsp = safe_require('utils.bsp')
M.ddx = require('utils.ddx')
M.docs = require('utils.docs')
M.media = require('utils.media')
M.options = require('utils.options')
M.red = safe_require('utils.red')
M.dev = safe_require('utils.dev')
if M.dev and M.dev.setup then
	M.dev.setup()
end

if M.bsp and M.bsp.setup then
	M.bsp.setup({
		cargo = true,
		auto_detect = true,
		cargo_bsp_binary = 'cargo-bsp',
	})
end

M.ux = safe_require('utils.ux')
M.dictionary = {
	path = vim.fn.stdpath('config') .. '/lua/utils/docs/dictionary',
	file = 'words.txt',
	load_words = function()
		local dict = vim.fn.stdpath('config') .. '/lua/utils/docs/dictionary/words.txt'
		local f = io.open(dict, 'r')
		if not f then
			vim.notify('Failed to open dictionary: ' .. dict, vim.log.levels.WARN)
			return {}
		end
		local t = {}
		for line in f:lines() do
			t[#t + 1] = line
		end
		f:close()
		return t
	end,
}
M.spell = {
	file = vim.fn.stdpath('config') .. '/spell/en.utf-8.add',
	ensure = function()
		local dir = vim.fn.fnamemodify(M.spell.file, ':h')
		vim.fn.mkdir(dir, 'p')
		if vim.fn.filereadable(M.spell.file) == 0 then
			local f = io.open(M.spell.file, 'w')
			if f then
				f:close()
			end
		end
	end,
	setup_buffer = function(bufnr)
		bufnr = bufnr or 0
		local bo = vim.bo[bufnr]
		bo.spell = true
		bo.spelllang = 'en'
		bo.spellfile = M.spell.file
	end,
	add_word = function(word)
		if not word or word == '' then
			vim.notify('No word provided', vim.log.levels.WARN)
			return
		end
		M.spell.ensure()
		vim.opt.spellfile = M.spell.file
		vim.cmd('silent spellgood ' .. vim.fn.fnameescape(word))
		vim.cmd(
			'silent! mkspell! ' .. vim.fn.fnameescape(M.spell.file .. '.spl') .. ' ' .. vim.fn.fnameescape(M.spell.file)
		)
		vim.notify('Added to spellfile: ' .. word, vim.log.levels.INFO)
	end,
	add_from_dictionary = function()
		local words = M.dictionary.load_words()
		if not words or vim.tbl_isempty(words) then
			vim.notify('Dictionary is empty', vim.log.levels.WARN)
			return
		end
		vim.ui.select(words, {
			prompt = 'Add dictionary word to spellfile',
			format_item = function(item)
				return item
			end,
		}, function(choice)
			if choice then
				M.spell.add_word(choice)
			end
		end)
	end,
}
return M
