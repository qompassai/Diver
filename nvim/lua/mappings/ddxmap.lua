-- /qompassai/Diver/lua/mappings/ddxmap.lua
-- Qompass AI Diver Native Diagnostics and Debug Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
------------------------------------------------------------
---@module 'mappings.ddxmap'
local M = {}
local api = vim.api
local levels = vim.log.levels
local uv = vim.uv
local configured = false
---@param name? string
---@return boolean
local function local_dap_module_exists(name)
	local root = vim.fs.joinpath(vim.fn.stdpath('config'), 'lua', 'dap')
	if name == nil then
		return uv.fs_stat(vim.fs.joinpath(root, 'init.lua')) ~= nil
	end

	return uv.fs_stat(vim.fs.joinpath(root, name .. '.lua')) ~= nil
		or uv.fs_stat(vim.fs.joinpath(root, name, 'init.lua')) ~= nil
end

---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param description string
local function set_global_map(mode, lhs, rhs, description)
	vim.keymap.set(mode, lhs, rhs, {
		desc = description,
		silent = true,
	})
end

---@param bufnr integer
---@param lhs string
---@param command string
---@param description string
local function set_android_map(bufnr, lhs, command, description)
	vim.keymap.set('n', lhs, '<Cmd>' .. command .. '<CR>', {
		buffer = bufnr,
		desc = description,
		silent = true,
	})
end

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or levels.INFO, {
		title = 'Native DAP mappings',
	})
end

---@param report? boolean
---@return table?
local function debug_api(report)
	if type(vim.debug) == 'table' then
		return vim.debug
	end

	if not local_dap_module_exists() then
		if report ~= false then
			notify('Native DAP is unavailable; expected $XDG_CONFIG_HOME/nvim/lua/dap/init.lua', levels.ERROR)
		end
		return nil
	end

	local ok, native = pcall(require, 'dap')
	if type(vim.debug) == 'table' then
		return vim.debug
	end
	if ok and type(native) == 'table' then
		return native
	end

	if report ~= false then
		notify(
			'Native DAP is unavailable; expected lua/dap/init.lua to provide vim.debug or return its API table',
			levels.ERROR
		)
	end
	return nil
end

---@param name string
---@return table?
local function debug_component(name)
	local debug = debug_api(false)
	if debug and type(debug[name]) == 'table' then
		return debug[name]
	end

	if not local_dap_module_exists(name) then
		return nil
	end

	local ok, component = pcall(require, 'dap.' .. name)
	if ok and type(component) == 'table' then
		return component
	end
	return nil
end

---@param methods string|string[]
---@param description string
---@return boolean
local function call_debug(methods, description)
	local debug = debug_api()
	if not debug then
		return false
	end

	local candidates = type(methods) == 'table' and methods or { methods }
	for _, method in ipairs(candidates) do
		local callback = debug[method]
		if type(callback) == 'function' then
			local ok, err = pcall(callback)
			if not ok then
				notify(('%s failed: %s'):format(description, tostring(err)), levels.ERROR)
				return false
			end
			return true
		end
	end

	notify(('%s is not implemented by the native DAP client'):format(description), levels.WARN)
	return false
end

local function toggle_breakpoint()
	local debug = debug_api()
	if not debug then
		return
	end

	if type(debug.toggle_breakpoint) == 'function' then
		local ok, err = pcall(debug.toggle_breakpoint)
		if not ok then
			notify(('Toggle breakpoint failed: %s'):format(tostring(err)), levels.ERROR)
		end
		return
	end

	local breakpoints = debug_component('breakpoints')
	if breakpoints then
		local callback = breakpoints.toggle or breakpoints.toggle_breakpoint
		if type(callback) == 'function' then
			local ok, err = pcall(callback)
			if not ok then
				notify(('Toggle breakpoint failed: %s'):format(tostring(err)), levels.ERROR)
			end
			return
		end
	end

	notify('Breakpoint toggling is not implemented by the native DAP client', levels.WARN)
end

---@param name 'repl'|'ui'
---@param description string
local function toggle_component(name, description)
	local component = debug_component(name)
	if not component then
		notify(('%s is unavailable in lua/dap/%s.lua'):format(description, name), levels.WARN)
		return
	end

	local callback = component.toggle or component.open
	if type(callback) ~= 'function' then
		notify(('%s does not provide toggle() or open()'):format(description), levels.WARN)
		return
	end

	local ok, err = pcall(callback)
	if not ok then
		notify(('%s failed: %s'):format(description, tostring(err)), levels.ERROR)
	end
end

local function enable_verbose_logging()
	local enabled = false
	local debug = debug_api(false)

	if debug and type(debug.set_log_level) == 'function' then
		local ok, err = pcall(debug.set_log_level, 'debug')
		if not ok then
			notify(('Unable to set native DAP log level: %s'):format(tostring(err)), levels.ERROR)
			return
		end
		enabled = true
	else
		local log = debug_component('log')
		if log then
			local callback = log.set_level or log.set_log_level
			if type(callback) == 'function' then
				local ok, err = pcall(callback, 'debug')
				if not ok then
					notify(('Unable to set native DAP log level: %s'):format(tostring(err)), levels.ERROR)
					return
				end
				enabled = true
			end
		end
	end

	if vim.lsp and vim.lsp.log and type(vim.lsp.log.set_level) == 'function' then
		vim.lsp.log.set_level('debug')
	end

	if enabled then
		notify('Native DAP and LSP debug logging enabled')
	else
		notify('LSP debug logging enabled; native DAP has no log-level setter', levels.WARN)
	end
end

local function toggle_virtual_lines()
	local config = vim.diagnostic.config() or {}
	local enabled = not not config.virtual_lines
	vim.diagnostic.config({
		virtual_lines = not enabled,
		virtual_text = enabled,
	})
	notify(('Diagnostic virtual lines %s'):format(enabled and 'disabled' or 'enabled'))
end
---@param value unknown
---@return integer?
local function to_integer(value)
	if type(value) ~= 'number' or value % 1 ~= 0 then
		return nil
	end
	---@cast value integer
	return value
end
local function setup_android_mappings(bufnr) ---@param bufnr integer
	set_android_map(bufnr, '<leader>dad', 'AndroidSelectDevice', 'Android select device')
	set_android_map(bufnr, '<leader>dal', 'AndroidLaunch', 'Android launch app')
	set_android_map(bufnr, '<leader>dac', 'AndroidClearDebugApp', 'Android clear debug app')
	set_android_map(bufnr, '<leader>daf', 'AndroidForwardJdwp', 'Android forward JDWP')
	set_android_map(bufnr, '<leader>daj', 'AndroidAttachJdb', 'Android attach jdb')
	set_android_map(bufnr, '<leader>dax', 'AndroidClearForwards', 'Android clear forwards')
	set_android_map(bufnr, '<leader>dan', 'AndroidNativeAttach', 'Android native attach')
	set_android_map(bufnr, '<leader>dag', 'AndroidLogcat', 'Android logcat')
end
local function setup_android_autocmd()
	local group = api.nvim_create_augroup('qompass_android_dap_mappings', {
		clear = true,
	})
	api.nvim_create_autocmd('User', {
		group = group,
		pattern = 'AndroidDapConfigured',
		callback = function(args)
			local data = args.data
			if type(data) ~= 'table' then
				return
			end
			local bufnr = to_integer(data.bufnr)
			if bufnr == nil or not api.nvim_buf_is_valid(bufnr) then
				return
			end
			setup_android_mappings(bufnr)
		end,
	})
end

function M.setup_ddxmap()
	if configured then
		return
	end
	configured = true
	set_global_map('n', 'SC', '<Cmd>ConfigSelfCheck<CR>', 'Configuration: run self-check')
	set_global_map('n', 'SL', '<Cmd>ConfigSelfCheckLog<CR>', 'Configuration: open self-check log')
	set_global_map('n', 'SS', '<Cmd>ConfigSyntaxCheck<CR>', 'Configuration: run syntax check')
	set_global_map('n', 'dl', toggle_virtual_lines, 'Diagnostics: toggle virtual lines globally')
	set_global_map('n', 'df', function()
		vim.diagnostic.open_float(nil, {
			scope = 'line',
		})
	end, 'Diagnostics: show current line')
	set_global_map('n', 'dq', function()
		vim.diagnostic.setqflist({
			open = true,
		})
	end, 'Diagnostics: open quickfix list')
	set_global_map('n', 'dQ', function()
		vim.diagnostic.setloclist({
			open = true,
		})
	end, 'Diagnostics: open location list')
	set_global_map('n', 'ds', function()
		call_debug('continue', 'Continue debugging')
	end, 'Debug: start or continue')
	set_global_map('n', 'db', toggle_breakpoint, 'Debug: toggle breakpoint')
	set_global_map('n', 'dS', function()
		call_debug('step_over', 'Step over')
	end, 'Debug: step over')
	set_global_map('n', 'di', function()
		call_debug('step_into', 'Step into')
	end, 'Debug: step into')
	set_global_map('n', 'do', function()
		call_debug('step_out', 'Step out')
	end, 'Debug: step out')
	set_global_map('n', 'dp', function()
		call_debug('pause', 'Pause debugging')
	end, 'Debug: pause')
	set_global_map('n', 'dt', function()
		call_debug({
			'terminate',
			'stop',
		}, 'Terminate debugging')
	end, 'Debug: terminate')
	set_global_map('n', 'dR', function()
		call_debug('restart', 'Restart debugging')
	end, 'Debug: restart')
	set_global_map('n', 'dL', function()
		call_debug('run_last', 'Run last debug configuration')
	end, 'Debug: run last configuration')
	set_global_map('n', 'dr', function()
		toggle_component('repl', 'Native DAP REPL')
	end, 'Debug: toggle native REPL')
	set_global_map('n', 'du', function()
		toggle_component('ui', 'Native DAP UI')
	end, 'Debug: toggle native UI')
	set_global_map('n', 'dv', enable_verbose_logging, 'Debug: enable verbose logging')
	setup_android_autocmd()
end

return M
