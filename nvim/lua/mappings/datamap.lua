-- /qompassai/Diver/lua/mappings/datamap.lua
-- Qompass AI Diver Data  Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
local api = vim.api
local math_namespace = api.nvim_create_namespace('math_annotations')
---@param bufnr integer
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param desc string
local function buf_map(bufnr, mode, lhs, rhs, desc)
	vim.keymap.set(mode, lhs, rhs, {
		buffer = bufnr,
		desc = desc,
		silent = true,
	})
end
---@param line string
---@return string?
local function extract_math(line)
	return line:match('%$%$(.-)%$%$') or line:match('%$(.-)%$')
end
local function toggle_line_math(bufnr) ---@param bufnr integer
	local lnum = api.nvim_win_get_cursor(0)[1] - 1
	local marks = api.nvim_buf_get_extmarks(bufnr, math_namespace, {
		lnum,
		0,
	}, {
		lnum,
		-1,
	}, {})
	if #marks > 0 then
		api.nvim_buf_clear_namespace(bufnr, math_namespace, lnum, lnum + 1)
		return
	end
	local line = api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''
	local math = extract_math(line)
	if not math then
		vim.notify('No inline or display math found on this line', vim.log.levels.INFO, {
			title = 'Math annotations',
		})
		return
	end
	api.nvim_buf_set_extmark(bufnr, math_namespace, lnum, -1, {
		virt_text = {
			{
				' ⟹ ' .. math,
				'Comment',
			},
		},
		virt_text_pos = 'eol',
	})
end
local function toggle_all_math(bufnr) ---@param bufnr integer
	if vim.b[bufnr].math_annotations then
		api.nvim_buf_clear_namespace(bufnr, math_namespace, 0, -1)
		vim.b[bufnr].qompass_math_annotations = false
		return
	end
	vim.b[bufnr].qompass_math_annotations = true
	for index, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		local math = extract_math(line)
		if math then
			api.nvim_buf_set_extmark(bufnr, math_namespace, index - 1, -1, {
				virt_text = {
					{ ' ⟹ ' .. math, 'Comment' },
				},
				virt_text_pos = 'eol',
			})
		end
	end
end
---@param group integer
local function setup_math_maps(group)
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = {
			'markdown',
			'markdown_inline',
			'plaintex',
			'quarto',
			'tex',
		},
		callback = function(args)
			local bufnr = args.buf
			buf_map(bufnr, 'n', '<leader>ml', function()
				toggle_line_math(bufnr)
			end, 'Math: toggle current-line annotation')
			buf_map(bufnr, 'n', '<leader>ma', function()
				toggle_all_math(bufnr)
			end, 'Math: toggle all annotations')
		end,
	})
end
local function setup_sf_query_maps(group) ---@param group integer
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = { 'soql', 'sosl' },
		callback = function(args)
			local bufnr = args.buf
			local filetype = vim.bo[bufnr].filetype
			if filetype == 'soql' then
				buf_map(bufnr, 'n', '<leader>sfr', '<cmd>SfSoqlRun<cr>', 'Salesforce: run SOQL')
				buf_map(bufnr, 'n', '<leader>sft', '<cmd>SfSoqlTemplate<cr>', 'Salesforce: SOQL template')
			elseif filetype == 'sosl' then
				buf_map(bufnr, 'n', '<leader>sfr', '<cmd>SfSoslRun<cr>', 'Salesforce: run SOSL')
				buf_map(bufnr, 'n', '<leader>sft', '<cmd>SfSoslTemplate<cr>', 'Salesforce: SOSL template')
			end
			buf_map(bufnr, 'n', '<leader>sfl', '<cmd>SfQueryLint<cr>', 'Salesforce: lint query')
			buf_map(bufnr, 'n', '<leader>sfR', '<cmd>SfQueryRun<cr>', 'Salesforce: run query automatically')
		end,
	})
end
function M.setup_datamap()
	if M.configured then
		return
	end
	M.configured = true
	local group = api.nvim_create_augroup('DataMappings', {
		clear = true,
	})
	setup_math_maps(group)
	setup_sf_query_maps(group)
end
return M
