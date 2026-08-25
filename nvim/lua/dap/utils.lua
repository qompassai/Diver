--[[# #################################################################
# /qompassai/lua/dap/utils.lua
# Qompass AI Utils
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2026 Qompass AI
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# #################################################################
--]]
local M = {}
---@class dap.utils.Proc
---@field pid integer
---@field name string
---@class dap.utils.GetProcessesOpts
---@field filter? string|fun(proc: dap.utils.Proc): boolean
---@class dap.utils.PickProcessOpts: dap.utils.GetProcessesOpts
---@field label? fun(proc: dap.utils.Proc): string
---@field prompt? string
---@class dap.utils.GetFilesOpts
---@field filter? string|fun(name: string): boolean
---@field executables? boolean
---@class dap.utils.PickFileOpts: dap.utils.GetFilesOpts
---@field path? string
---@param err dap.ErrorResponse
---@return string?
function M.fmt_error(err)
	local body = err.body or {}
	local structured = body.error
	if structured and structured.showUser then
		local message = structured.format or err.message
		if type(message) ~= 'string' then
			return nil
		end
		for key, value in pairs(structured.variables or {}) do
			local placeholder = '{' .. vim.pesc(tostring(key)) .. '}'
			message = message:gsub(placeholder, function()
				return tostring(value)
			end)
		end
		return message
	end
	return err.message
end

---@deprecated
---@generic T
---@param values? table<any, T>
---@param get_key fun(value: T): any
---@param get_value? fun(value: T): any
---@return table<any, any>
function M.to_dict(values, get_key, get_value)
	if vim.notify_once then
		vim.notify_once('dap.utils.to_dict is deprecated for removal in nvim-dap 0.10.0')
	end
	local result = {}
	local value_fn = get_value or function(value)
		return value
	end
	for _, value in pairs(values or {}) do
		result[get_key(value)] = value_fn(value)
	end
	return result
end
---@param object? table|string
---@return boolean
function M.non_empty(object)
	if type(object) == 'table' then
		return next(object) ~= nil
	end

	return type(object) == 'string' and object ~= ''
end

---@generic T
---@param items T[]
---@param predicate fun(item: T): boolean
---@return integer?
function M.index_of(items, predicate)
	for index, item in ipairs(items) do
		if predicate(item) then
			return index
		end
	end

	return nil
end

---@param message string
---@param log_level? integer
function M.notify(message, log_level)
	local function send()
		vim.notify(message, log_level, {
			title = 'DAP',
		})
	end

	if vim.in_fast_event() then
		vim.schedule(send)
	else
		send()
	end
end

---@param value string
---@return string
local function absolute_path(value)
	return vim.fs.normalize(vim.fn.fnamemodify(value, ':p'))
end

---@return string[]
local function process_command()
	if vim.fn.has('win32') == 1 then
		return {
			'tasklist',
			'/nh',
			'/fo',
			'csv',
		}
	end

	local command = {
		'ps',
		'ah',
	}
	local user = vim.env.USER

	if type(user) == 'string' and user ~= '' then
		command[#command + 1] = '-U'
		command[#command + 1] = user
	end

	return command
end

---@param parts string[]
---@param is_windows boolean
---@return string
local function process_pid(parts, is_windows)
	if is_windows then
		return vim.fn.trim(parts[2] or '', '"')
	end

	return parts[1] or ''
end

---@param parts string[]
---@param is_windows boolean
---@return string
local function process_name(parts, is_windows)
	if is_windows then
		return vim.fn.trim(parts[1] or '', '"')
	end

	if #parts < 5 then
		return ''
	end

	local command = {}
	for index = 5, #parts do
		command[#command + 1] = parts[index]
	end

	return table.concat(command, ' ')
end

---@param configured_filter string|fun(proc: dap.utils.Proc): boolean
---@return fun(proc: dap.utils.Proc): boolean
local function process_filter(configured_filter)
	if type(configured_filter) == 'string' then
		local pattern = configured_filter

		return function(process)
			return process.name:find(pattern) ~= nil
		end
	end

	if type(configured_filter) == 'function' then
		local predicate = configured_filter

		return function(process)
			return predicate(process) == true
		end
	end

	error('opts.filter must be a string or a function')
end

---Return running processes as a list of `{ pid, name }` tables.
---
---The optional filter can be a Lua pattern or a predicate receiving a
---`dap.utils.Proc`. Matching processes are included.
---@param opts? dap.utils.GetProcessesOpts
---@return dap.utils.Proc[]
function M.get_processes(opts)
	opts = opts or {}

	local is_windows = vim.fn.has('win32') == 1
	local separator = is_windows and ',' or ' \\+'
	local result = vim.system(process_command(), {
		text = true,
	}):wait()

	if result.code ~= 0 then
		local message = result.stderr
		if type(message) ~= 'string' or message == '' then
			message = 'Unable to enumerate running processes'
		end
		M.notify(vim.trim(message), vim.log.levels.ERROR)
		return {}
	end
	local processes = {}
	local nvim_pid = vim.fn.getpid()
	for _, line in
		ipairs(vim.split(result.stdout or '', '\n', {
			plain = true,
			trimempty = true,
		}))
	do
		local parts = vim.fn.split(vim.trim(line), separator)
		local raw_pid = process_pid(parts, is_windows)
		local parsed_pid = tonumber(raw_pid)
		local name = process_name(parts, is_windows)

		if parsed_pid and parsed_pid > 0 and parsed_pid % 1 == 0 and parsed_pid ~= nvim_pid then
			parsed_pid = math.floor(parsed_pid)
			---@cast parsed_pid integer
			processes[#processes + 1] = {
				pid = parsed_pid,
				name = name,
			}
		end
	end
	if opts.filter then
		processes = vim.tbl_filter(process_filter(opts.filter), processes)
	end
	return processes
end

---@param name string
---@param columns integer
---@param wordlimit integer
---@return string
local function trim_procname(name, columns, wordlimit)
	if #name <= columns then
		return name
	end

	---@param part string
	---@param index integer
	---@return string
	local function trim_part(part, index)
		if #part <= wordlimit then
			return part
		end

		local basename = part:gsub('(/?[^/]+/)', '')

		if index > 1 and #basename > wordlimit then
			return '‥' .. basename:sub(#basename - wordlimit + 1)
		end
		return basename
	end
	local parts = {}
	local length = 0
	local count = 0
	for word in name:gmatch('[^%s]+') do
		count = count + 1
		local trimmed = trim_part(word, count)
		local separator_length = count > 1 and 1 or 0

		if count > 1 and length + separator_length + #trimmed > columns then
			parts[#parts + 1] = '[‥]'
			break
		end

		parts[#parts + 1] = trimmed
		length = length + separator_length + #trimmed
	end

	if #parts > 0 then
		return table.concat(parts, ' ')
	end

	return trim_part(name, 1)
end

---@private
M._trim_procname = trim_procname

---Show a process picker and return the selected process ID.
---@param opts? dap.utils.PickProcessOpts
---@return integer|dap.Abort
function M.pick_process(opts)
	opts = opts or {}

	local columns = math.max(14, math.floor(vim.o.columns * 0.7))
	local wordlimit = math.max(10, math.floor(columns / 3))

	---@type fun(proc: dap.utils.Proc): string
	local label
	if opts.label then
		label = opts.label
	else
		label = function(process)
			local name = trim_procname(process.name, columns, wordlimit)
			return string.format('id=%d name=%s', process.pid, name)
		end
	end

	local processes = M.get_processes({
		filter = opts.filter,
	})
	local coroutine_handle, is_main = coroutine.running()
	local ui = require('dap.ui')

	---@type dap.utils.Proc?
	local selected
	if coroutine_handle and not is_main then
		selected = ui.pick_one(processes, opts.prompt or 'Select process: ', label)
	else
		selected = ui.pick_one_sync(processes, opts.prompt or 'Select process: ', label)
	end

	return selected and selected.pid or require('dap').ABORT
end

---@generic T
---@param value T?
---@param default T
---@return T
function M.if_nil(value, default)
	if value == nil then
		return default
	end

	return value
end

---@param configured_filter string|fun(name: string): boolean
---@return fun(filepath: string): boolean
local function file_filter(configured_filter)
	if type(configured_filter) == 'string' then
		local pattern = configured_filter

		return function(filepath)
			return filepath:find(pattern) ~= nil
		end
	end

	if type(configured_filter) == 'function' then
		local predicate = configured_filter

		return function(filepath)
			return predicate(filepath) == true
		end
	end

	error('opts.filter must be a string or a function')
end

---@param path string
---@param opts dap.utils.GetFilesOpts
---@return string[]
local function get_files(path, opts)
	local stat = vim.uv.fs_stat(path)
	if not stat or stat.type ~= 'directory' then
		M.notify('File selection path is not a directory: ' .. path, vim.log.levels.ERROR)
		return {}
	end

	---@type fun(filepath: string): boolean
	local filter = function()
		return true
	end

	if opts.filter then
		filter = file_filter(opts.filter)
	end

	if opts.executables then
		local previous_filter = filter
		filter = function(filepath)
			return previous_filter(filepath) and vim.fn.executable(filepath) == 1
		end
	end

	if vim.fs.dir then
		local files = {}

		for name, kind in
			vim.fs.dir(path, {
				depth = 50,
			})
		do
			if kind == 'file' then
				local filepath = vim.fs.joinpath(path, name)
				if filter(filepath) then
					files[#files + 1] = filepath
				end
			end
		end

		table.sort(files)
		return files
	end

	if vim.fn.executable('find') ~= 1 then
		M.notify('File selection requires vim.fs.dir() or find(1)', vim.log.levels.ERROR)
		return {}
	end

	local command = {
		'find',
		'-L',
		path,
		'-type',
		'f',
	}
	if opts.executables then
		command[#command + 1] = '-executable'
	end

	local result = vim.system(command, {
		text = true,
	}):wait()
	if result.code ~= 0 then
		local message = result.stderr
		if type(message) ~= 'string' or message == '' then
			message = 'Unable to enumerate files under ' .. path
		end
		M.notify(vim.trim(message), vim.log.levels.ERROR)
		return {}
	end

	return vim.tbl_filter(
		filter,
		vim.split(result.stdout or '', '\n', {
			plain = true,
			trimempty = true,
		})
	)
end
---@param opts? dap.utils.PickFileOpts
---@return thread|string|dap.Abort
function M.pick_file(opts)
	opts = opts or {}
	local executables = opts.executables ~= false
	local path = absolute_path(opts.path or vim.fn.getcwd())
	local files = get_files(path, {
		filter = opts.filter,
		executables = executables,
	})
	local prompt = executables and 'Select executable: ' or 'Select file: '
	local coroutine_handle, is_main = coroutine.running()
	local ui = require('dap.ui')
	local prefix = vim.endswith(path, '/') and path or path .. '/'
	---@param filepath string
	---@return string
	local function relative_path(filepath)
		if vim.startswith(filepath, prefix) then
			return filepath:sub(#prefix + 1)
		end
		return filepath
	end
	if coroutine_handle and not is_main then
		return ui.pick_one(files, prompt, relative_path) or require('dap').ABORT
	end
	return ui.pick_one_sync(files, prompt, relative_path) or require('dap').ABORT
end
---Split an argument string on whitespace, preserving quoted substrings.
---@param value string
---@return string[]
function M.splitstr(value)
	local lpeg = vim.lpeg
	local P, S, C = lpeg.P, lpeg.S, lpeg.C
	---@param quote_string string
	---@return vim.lpeg.Pattern
	local function quoted_text(quote_string)
		local quote = P(quote_string)
		local escaped_quote = P('\\') * quote
		return quote * C(((1 - quote) + escaped_quote) ^ 0) * quote
	end
	local trimmed = value:match('^%s*(.-)%s*$')
	if not trimmed or trimmed == '' then
		return {}
	end
	local whitespace = S(' \t\n\r')
	local unquoted = P('\\') * C(P(1)) + C(P(1) - whitespace)
	local word = quoted_text('"') + quoted_text("'") + unquoted
	local element = lpeg.Cf(word ^ 1, function(accumulator, part)
		return accumulator .. part
	end)
	local pattern = lpeg.Ct(element * (whitespace ^ 1 * element) ^ 0)
	local result = lpeg.match(pattern, trimmed)

	return type(result) == 'table' and result or {}
end
return M
