-- float.lua
-- Qompass AI Diver UI Float Module
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
local api = vim.api
local fn = vim.fn
local M = {}
local defaults = {
	close_on_switch = true,
	cmd = function()
		return {
			vim.o.shell,
		}
	end,
	cwd = function()
		return fn.getcwd()
	end,
	file = nil,
	focus = true,
	id = nil,
	on_exit = nil,
	on_open = nil,
	start_in_insert = true,
	window = {
		anchor = 'NW',
		border = 'rounded',
		col = nil,
		footer = nil,
		footer_pos = 'left',
		focusable = true,
		h_align = 'center',
		height = 0.8,
		mouse = true,
		noautocmd = false,
		relative = 'editor',
		row = nil,
		style = 'minimal',
		title = ' Terminal ',
		title_pos = 'center',
		v_align = 'center',
		width = 0.8,
		zindex = 50,
	},
	wo = {
		cursorcolumn = false,
		cursorline = false,
		cursorlineopt = 'both',
		fillchars = 'eob: ,lastline:…',
		list = false,
		listchars = 'extends:…,tab:  ',
		number = false,
		relativenumber = false,
		scrolloff = 0,
		sidescrolloff = 0,
		signcolumn = 'no',
		spell = false,
		statuscolumn = '',
		winbar = '',
		wrap = false,
	},
}

M.config = vim.deepcopy(defaults)
M.state = {
	instances = {},
	previous_id = 1,
	setup = false,
}

---@param value any
---@param ... any
---@return any
local function evaluate(value, ...)
	if type(value) == 'function' then
		return value(...)
	end
	return value
end

---@param buf integer|nil
---@return boolean
local function valid_buffer(buf)
	return type(buf) == 'number' and api.nvim_buf_is_valid(buf)
end

---@param win integer|nil
---@return boolean
local function valid_window(win)
	return type(win) == 'number' and api.nvim_win_is_valid(win)
end

---@param value any
---@param fallback boolean
---@return boolean
local function as_boolean(value, fallback)
	value = evaluate(value)
	if type(value) == 'boolean' then
		return value
	end
	return fallback
end

---@param value any
---@param available integer
---@param fallback number
---@return integer
local function dimension(value, available, fallback)
	value = tonumber(evaluate(value)) or fallback
	local result

	if value > 0 and value <= 1 then
		result = math.floor(available * value)
	else
		result = math.floor(value)
	end

	result = math.max(1, math.min(result, available))
	---@cast result integer
	return result
end

---@param border any
---@return integer
local function border_size(border)
	if border == nil or border == '' or border == 'none' then
		return 0
	end
	return 2
end

---@param requested any
---@param alignment string
---@param available integer
---@param occupied integer
---@return integer
local function position(requested, alignment, available, occupied)
	local maximum = math.max(0, available - occupied)
	local value = tonumber(evaluate(requested))

	if value then
		if value > 0 and value < 1 then
			value = math.floor(maximum * value)
		else
			value = math.floor(value)
		end
	elseif alignment == 'top' or alignment == 'left' then
		value = 0
	elseif alignment == 'bottom' or alignment == 'right' then
		value = maximum
	else
		value = math.floor(maximum / 2)
	end

	value = math.max(0, math.min(value, maximum))
	---@cast value integer
	return value
end

---@param opts table|nil
---@return table
local function merged_config(opts)
	return vim.tbl_deep_extend('force', {}, M.config, opts or {})
end

---@param window table
---@return table
local function window_config(window)
	local columns = math.max(1, vim.o.columns)
	local lines = math.max(1, vim.o.lines - vim.o.cmdheight)
	local border = evaluate(window.border)
	local border_width = border_size(border)
	local border_height = border_size(border)
	local available_width = math.max(1, columns - border_width)
	local available_height = math.max(1, lines - border_height)
	local width = dimension(window.width, available_width, 0.8)
	local height = dimension(window.height, available_height, 0.8)
	local row = position(window.row, window.v_align or 'center', lines, height + border_height)
	local col = position(window.col, window.h_align or 'center', columns, width + border_width)

	local zindex = math.max(1, math.floor(tonumber(evaluate(window.zindex)) or 50))
	---@cast zindex integer

	local config = {
		anchor = evaluate(window.anchor) or 'NW',
		border = border,
		col = col,
		focusable = as_boolean(window.focusable, true),
		height = height,
		mouse = as_boolean(window.mouse, true),
		noautocmd = as_boolean(window.noautocmd, false),
		relative = evaluate(window.relative) or 'editor',
		row = row,
		style = evaluate(window.style) or 'minimal',
		width = width,
		zindex = zindex,
	}

	local title = evaluate(window.title)
	if title and title ~= '' then
		config.title = title
		config.title_pos = evaluate(window.title_pos) or 'center'
	end

	local footer = evaluate(window.footer)
	if footer and footer ~= '' then
		config.footer = footer
		config.footer_pos = evaluate(window.footer_pos) or 'left'
	end

	return config
end

---@param win integer
---@param options table
local function apply_window_options(win, options)
	for name, value in pairs(options) do
		pcall(api.nvim_set_option_value, name, evaluate(value), {
			win = win,
		})
	end
end

---@param id string|integer
---@param buf integer
local function attach_buffer_cleanup(id, buf)
	api.nvim_create_autocmd('BufWipeout', {
		buffer = buf,
		callback = function()
			local instance = M.state.instances[id]
			if instance and instance.buf == buf then
				M.state.instances[id] = nil
			end
		end,
		once = true,
	})
end

---@param config table
---@return integer, boolean
local function create_buffer(config)
	local file = evaluate(config.file)

	if type(file) == 'string' and file ~= '' then
		local path = fn.fnamemodify(file, ':p')
		local buf = fn.bufadd(path)
		fn.bufload(buf)
		return buf, false
	end

	local buf = api.nvim_create_buf(false, true)
	api.nvim_set_option_value('bufhidden', 'hide', {
		buf = buf,
	})
	api.nvim_set_option_value('swapfile', false, {
		buf = buf,
	})
	return buf, true
end

---@param job integer|nil
---@return boolean
local function job_running(job)
	if type(job) ~= 'number' or job <= 0 then
		return false
	end

	local result = fn.jobwait({
		job,
	}, 0)
	return result[1] == -1
end

---@param id string|integer
---@param instance table
---@param config table
---@return boolean
local function start_terminal(id, instance, config)
	if job_running(instance.job) then
		return true
	end

	local cmd = evaluate(config.cmd, id, instance)
	if type(cmd) ~= 'string' and type(cmd) ~= 'table' then
		vim.notify('Float command must resolve to a string or command list', vim.log.levels.ERROR, {
			title = 'Native float',
		})
		return false
	end

	local cwd = evaluate(config.cwd, id, instance)
	if type(cwd) ~= 'string' or cwd == '' or fn.isdirectory(cwd) ~= 1 then
		cwd = fn.getcwd()
	end

	local job = fn.jobstart(cmd, {
		cwd = cwd,
		on_exit = function(job_id, exit_code, event)
			vim.schedule(function()
				local current = M.state.instances[id]
				if current and current.job == job_id then
					current.job = nil
					current.exit_code = exit_code
				end

				if type(config.on_exit) == 'function' then
					pcall(config.on_exit, instance, exit_code, event)
				end
			end)
		end,
		term = true,
	})

	if job == 0 then
		vim.notify('Unable to start the terminal: invalid arguments', vim.log.levels.ERROR, {
			title = 'Native float',
		})
		return false
	end

	if job == -1 then
		vim.notify('Unable to start the terminal command', vim.log.levels.ERROR, {
			title = 'Native float',
		})
		return false
	end

	instance.job = job
	instance.exit_code = nil
	return true
end

---@param opts table
---@return string|integer
local function resolve_id(opts)
	local requested = evaluate(opts.id)
	if type(requested) == 'string' or type(requested) == 'number' then
		if requested ~= '' and requested ~= 0 then
			return requested
		end
	end

	if vim.v.count > 0 then
		local count = math.floor(vim.v.count)
		---@cast count integer
		return count
	end

	return M.state.previous_id or 1
end

---@param id string|integer
---@param config table
local function close_other_window(id, config)
	if not as_boolean(config.close_on_switch, true) then
		return
	end

	local previous = M.state.instances[M.state.previous_id]
	if M.state.previous_id ~= id and previous and valid_window(previous.win) then
		api.nvim_win_close(previous.win, true)
		previous.win = nil
	end
end

---@param opts table|nil
---@return table|nil
function M.open(opts)
	local config = merged_config(opts)
	local id = resolve_id(config)
	local instance = M.state.instances[id]

	if instance and valid_window(instance.win) then
		if as_boolean(config.focus, true) then
			api.nvim_set_current_win(instance.win)
		end
		return instance
	end

	close_other_window(id, config)

	local created = false
	if not instance or not valid_buffer(instance.buf) then
		local buf, terminal = create_buffer(config)
		instance = {
			buf = buf,
			config = config,
			exit_code = nil,
			id = id,
			job = nil,
			terminal = terminal,
			win = nil,
		}
		M.state.instances[id] = instance
		created = true
		attach_buffer_cleanup(id, buf)
	else
		instance.config = config
	end

	local previous_win = api.nvim_get_current_win()
	local ok, win = pcall(api.nvim_open_win, instance.buf, true, window_config(config.window))

	if not ok then
		vim.notify('Unable to open floating window: ' .. tostring(win), vim.log.levels.ERROR, {
			title = 'Native float',
		})
		return nil
	end
	---@cast win integer

	instance.win = win
	apply_window_options(win, config.wo)

	if created and type(config.on_open) == 'function' then
		pcall(config.on_open, instance)
	end

	if instance.terminal and not start_terminal(id, instance, config) then
		M.close(id)
		return nil
	end

	M.state.previous_id = id

	local focus = as_boolean(config.focus, true)
	if not focus and valid_window(previous_win) then
		api.nvim_set_current_win(previous_win)
	elseif instance.terminal and as_boolean(config.start_in_insert, true) then
		vim.cmd.startinsert()
	end

	return instance
end

---@param id string|integer|nil
---@return boolean
function M.close(id)
	id = id or M.state.previous_id
	local instance = M.state.instances[id]
	if not instance then
		return false
	end

	if valid_window(instance.win) then
		api.nvim_win_close(instance.win, true)
	end
	instance.win = nil
	return true
end

---@param opts table|nil
---@return table|nil
function M.toggle(opts)
	local config = merged_config(opts)
	local id = resolve_id(config)
	local instance = M.state.instances[id]

	if instance and valid_window(instance.win) then
		M.close(id)
		return instance
	end

	config.id = id
	return M.open(config)
end

---@param id string|integer|nil
---@return boolean
function M.dispose(id)
	id = id or M.state.previous_id
	local instance = M.state.instances[id]
	if not instance then
		return false
	end

	M.close(id)
	if job_running(instance.job) then
		pcall(fn.jobstop, instance.job)
	end
	if valid_buffer(instance.buf) then
		pcall(api.nvim_buf_delete, instance.buf, {
			force = true,
		})
	end
	M.state.instances[id] = nil
	return true
end

---@param id string|integer|nil
---@param data string
---@return boolean
function M.send(id, data)
	id = id or M.state.previous_id
	local instance = M.state.instances[id]
	if not instance or not job_running(instance.job) then
		return false
	end

	return pcall(api.nvim_chan_send, instance.job, data)
end

---@param id string|integer|nil
---@return table|nil
function M.get(id)
	id = id or M.state.previous_id
	return M.state.instances[id]
end

---@param opts table|nil
function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend('force', {}, M.config, opts)
	end

	api.nvim_create_user_command('FloatTerminalToggle', function(args)
		local command = args.args ~= '' and args.args or nil
		local id = args.count > 0 and math.floor(args.count) or nil
		---@cast id integer|nil
		M.toggle({
			cmd = command,
			id = id,
		})
	end, {
		complete = 'shellcmd',
		count = true,
		desc = 'Toggle a native floating terminal',
		force = true,
		nargs = '*',
	})

	api.nvim_create_user_command('FloatTerminalClose', function(args)
		local id = args.count > 0 and math.floor(args.count) or nil
		---@cast id integer|nil
		M.close(id)
	end, {
		count = true,
		desc = 'Close a native floating terminal window',
		force = true,
	})

	api.nvim_create_user_command('FloatTerminalDispose', function(args)
		local id = args.count > 0 and math.floor(args.count) or nil
		---@cast id integer|nil
		M.dispose(id)
	end, {
		count = true,
		desc = 'Stop and delete a native floating terminal',
		force = true,
	})

	api.nvim_create_user_command('FloatTerminalStatus', function()
		local instance = M.get()
		if not instance then
			vim.notify('No floating terminal instance', vim.log.levels.INFO, {
				title = 'Native float',
			})
			return
		end

		local message = string.format(
			'id=%s buffer=%d window=%s job=%s',
			tostring(instance.id),
			instance.buf,
			valid_window(instance.win) and tostring(instance.win) or 'closed',
			job_running(instance.job) and tostring(instance.job) or 'stopped'
		)
		vim.notify(message, vim.log.levels.INFO, {
			title = 'Native float',
		})
	end, {
		desc = 'Show native floating terminal status',
		force = true,
	})

	M.state.setup = true
end

M.setup()

return M
