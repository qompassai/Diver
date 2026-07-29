-- padding.lua
-- Qompass AI Diver UI Padding Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local fn = vim.fn
local M = {}
local namespace = api.nvim_create_namespace('QompassSoftPadding')
local defaults = {
	auto_enable = {},
	debounce_ms = 80,
	default_mode = 'soft',
	dense = {
		highlight = 'Normal',
		run_min = 3,
		spacing = 1,
		text = ' ',
		threshold = 100,
	},
	max_lines = 50000,
	soft = {
		highlight = 'Normal',
		include_blank = true,
		include_last_line = false,
		spacing = 1,
		text = ' ',
	},
}
M.config = vim.deepcopy(defaults)
M.state = {
	buffers = {},
	setup = false,
}

---@class QompassPaddingState
---@field enabled boolean
---@field mode 'soft'|'dense'
---@field notified_limit boolean
---@field token integer

---@param bufnr integer|nil
---@return boolean
local function valid_buffer(bufnr)
	return type(bufnr) == 'number' and api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr)
end

---@param mode any
---@return 'soft'|'dense'|nil
local function valid_mode(mode)
	if mode == 'soft' or mode == 'dense' then
		return mode
	end
	return nil
end

---@param bufnr integer
---@return QompassPaddingState
local function buffer_state(bufnr)
	local state = M.state.buffers[bufnr]
	if state then
		return state
	end
	state = {
		enabled = false,
		mode = valid_mode(M.config.default_mode) or 'soft',
		notified_limit = false,
		token = 0,
	}
	M.state.buffers[bufnr] = state
	return state
end

---@param count integer
---@param text string
---@param highlight string
---@return table
local function virtual_lines(count, text, highlight)
	local lines = {}
	for _ = 1, math.max(0, count) do
		lines[#lines + 1] = {
			{
				text,
				highlight,
			},
		}
	end
	return lines
end

---@param bufnr integer
local function clear(bufnr)
	if api.nvim_buf_is_valid(bufnr) then
		api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
	end
end

---@param bufnr integer
---@param row integer
---@param config table
local function add_padding(bufnr, row, config)
	local spacing = math.max(0, math.floor(tonumber(config.spacing) or 0))
	---@cast spacing integer
	if spacing == 0 then
		return
	end

	api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
		priority = 10,
		right_gravity = false,
		undo_restore = false,
		virt_lines = virtual_lines(spacing, tostring(config.text or ' '), tostring(config.highlight or 'Normal')),
		virt_lines_above = false,
		virt_lines_overflow = 'trunc',
	})
end

---@param bufnr integer
---@param lines string[]
local function render_soft(bufnr, lines)
	local config = M.config.soft
	local final_index = #lines
	if not config.include_last_line then
		final_index = final_index - 1
	end

	for index = 1, math.max(0, final_index) do
		if config.include_blank or lines[index]:find('%S') then
			add_padding(bufnr, index - 1, config)
		end
	end
end

---@param bufnr integer
---@param first integer
---@param last integer
local function render_dense_run(bufnr, first, last)
	local config = M.config.dense
	local run_min = math.max(1, math.floor(tonumber(config.run_min) or 1))
	---@cast run_min integer
	if last < first or last - first + 1 < run_min then
		return
	end
	for index = first, last do
		add_padding(bufnr, index - 1, config)
	end
end
---@param bufnr integer
---@param lines string[]
local function render_dense(bufnr, lines)
	local threshold = math.max(1, math.floor(tonumber(M.config.dense.threshold) or 100))
	---@cast threshold integer
	local run_start

	for index, line in ipairs(lines) do
		if fn.strdisplaywidth(line) >= threshold then
			run_start = run_start or index
		elseif run_start then
			render_dense_run(bufnr, run_start, index - 1)
			run_start = nil
		end
	end

	if run_start then
		render_dense_run(bufnr, run_start, #lines)
	end
end

---@param bufnr integer
local function render(bufnr)
	if not valid_buffer(bufnr) then
		return
	end

	local state = M.state.buffers[bufnr]
	if not state or not state.enabled then
		clear(bufnr)
		return
	end

	clear(bufnr)

	local line_count = api.nvim_buf_line_count(bufnr)
	local max_lines = math.max(1, math.floor(tonumber(M.config.max_lines) or 50000))
	---@cast max_lines integer
	if line_count > max_lines then
		if not state.notified_limit then
			state.notified_limit = true
			vim.notify(
				string.format('Padding skipped: buffer has %d lines (limit: %d)', line_count, max_lines),
				vim.log.levels.WARN,
				{
					title = 'Native padding',
				}
			)
		end
		return
	end

	state.notified_limit = false
	local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if state.mode == 'dense' then
		render_dense(bufnr, lines)
	else
		render_soft(bufnr, lines)
	end
end

---@param bufnr integer
---@param delay integer|nil
local function schedule_render(bufnr, delay)
	local state = M.state.buffers[bufnr]
	if not state or not state.enabled then
		return
	end

	state.token = state.token + 1
	local token = state.token
	local timeout = math.max(0, math.floor(tonumber(delay) or tonumber(M.config.debounce_ms) or 80))
	---@cast timeout integer

	vim.defer_fn(function()
		local current = M.state.buffers[bufnr]
		if not current or current.token ~= token then
			return
		end
		render(bufnr)
	end, timeout)
end

---@param bufnr integer|nil
---@param mode 'soft'|'dense'|nil
function M.enable(bufnr, mode)
	bufnr = bufnr or api.nvim_get_current_buf()
	if not valid_buffer(bufnr) then
		return
	end

	local state = buffer_state(bufnr)
	state.enabled = true
	state.mode = valid_mode(mode) or state.mode
	schedule_render(bufnr, 0)
end

---@param bufnr integer|nil
function M.disable(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local state = M.state.buffers[bufnr]
	if state then
		state.enabled = false
		state.token = state.token + 1
	end
	clear(bufnr)
end

---@param mode 'soft'|'dense'|nil
---@param bufnr integer|nil
function M.toggle(mode, bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	if not valid_buffer(bufnr) then
		return
	end

	local state = buffer_state(bufnr)
	local requested = valid_mode(mode)
	if requested and requested ~= state.mode then
		state.mode = requested
		state.enabled = true
		schedule_render(bufnr, 0)
		return
	end

	if state.enabled then
		M.disable(bufnr)
	else
		M.enable(bufnr, requested)
	end
end

---@param mode 'soft'|'dense'
---@param bufnr integer|nil
function M.set_mode(mode, bufnr)
	local checked = valid_mode(mode)
	if not checked then
		vim.notify('Padding mode must be "soft" or "dense"', vim.log.levels.ERROR, {
			title = 'Native padding',
		})
		return
	end

	bufnr = bufnr or api.nvim_get_current_buf()
	if not valid_buffer(bufnr) then
		return
	end

	local state = buffer_state(bufnr)
	state.mode = checked
	if state.enabled then
		schedule_render(bufnr, 0)
	end
end

---@param bufnr integer|nil
function M.refresh(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	schedule_render(bufnr, 0)
end

---@param bufnr integer|nil
---@return boolean, 'soft'|'dense'
function M.status(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local state = buffer_state(bufnr)
	return state.enabled, state.mode
end

---@param opts table|nil
function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend('force', {}, M.config, opts)
	end

	local group = api.nvim_create_augroup('QompassNativePadding', {
		clear = true,
	})

	api.nvim_create_autocmd({
		'TextChanged',
		'TextChangedI',
	}, {
		callback = function(args)
			schedule_render(args.buf)
		end,
		group = group,
	})
	api.nvim_create_autocmd({
		'BufWinEnter',
		'WinEnter',
	}, {
		callback = function(args)
			local state = M.state.buffers[args.buf]
			if state and state.enabled then
				schedule_render(args.buf, 0)
			end
		end,
		group = group,
	})
	api.nvim_create_autocmd('FileType', {
		callback = function(args)
			local filetype = vim.bo[args.buf].filetype
			local setting = M.config.auto_enable[filetype]
			if setting == true then
				M.enable(args.buf)
			elseif valid_mode(setting) then
				M.enable(args.buf, setting)
			end
		end,
		group = group,
	})
	api.nvim_create_autocmd('BufWipeout', {
		callback = function(args)
			M.state.buffers[args.buf] = nil
		end,
		group = group,
	})
	api.nvim_create_user_command('PaddingEnable', function(args)
		M.enable(nil, valid_mode(args.args))
	end, {
		complete = function()
			return {
				'soft',
				'dense',
			}
		end,
		desc = 'Enable native virtual-line padding',
		force = true,
		nargs = '?',
	})
	api.nvim_create_user_command('PaddingDisable', function()
		M.disable()
	end, {
		desc = 'Disable native virtual-line padding',
		force = true,
	})

	api.nvim_create_user_command('PaddingToggle', function(args)
		M.toggle(valid_mode(args.args))
	end, {
		complete = function()
			return {
				'soft',
				'dense',
			}
		end,
		desc = 'Toggle native virtual-line padding',
		force = true,
		nargs = '?',
	})

	api.nvim_create_user_command('PaddingMode', function(args)
		M.set_mode(args.args)
	end, {
		complete = function()
			return {
				'soft',
				'dense',
			}
		end,
		desc = 'Set native padding mode',
		force = true,
		nargs = 1,
	})

	api.nvim_create_user_command('PaddingRefresh', function()
		M.refresh()
	end, {
		desc = 'Refresh native virtual-line padding',
		force = true,
	})

	api.nvim_create_user_command('PaddingStatus', function()
		local enabled, mode = M.status()
		vim.notify(string.format('enabled=%s mode=%s', tostring(enabled), mode), vim.log.levels.INFO, {
			title = 'Native padding',
		})
	end, {
		desc = 'Show native padding status',
		force = true,
	})

	for _, bufnr in ipairs(api.nvim_list_bufs()) do
		if valid_buffer(bufnr) then
			local filetype = vim.bo[bufnr].filetype
			local setting = M.config.auto_enable[filetype]
			if setting == true then
				M.enable(bufnr)
			elseif valid_mode(setting) then
				M.enable(bufnr, setting)
			end
		end
	end
	M.state.setup = true
end

M.setup()

return M
