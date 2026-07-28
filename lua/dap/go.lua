-- ~/.config/nvim/lua/dap/go.lua
-- Qompass AI Diver Go DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- -------------------------------------------------
-- This module intentionally does not configure LSP clients, diagnostics,
-- formatters, or linters. Existing Go tooling keeps its own lifecycle.

local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv

local M = {}

local FILETYPES = {
	go = true,
}

local FILETYPE_PATTERNS = {
	'go',
}

local FILE_PATTERNS = {
	'*.go',
}

local CONFIGURED_FLAG = 'qompass_go_dap_configured'

M.adapter = {
	name = 'delve',
	command = 'dlv',
	args = {
		'dap',
		'--listen=127.0.0.1:0',
	},
}

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.go',
	})
end

---@param command string
---@return boolean
local function executable(command)
	return fn.executable(command) == 1
end

---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end

---@param path string
---@return boolean
local function file_exists(path)
	return path ~= '' and uv.fs_stat(path) ~= nil
end

---@param path string
---@return boolean
local function is_executable(path)
	return file_exists(path) and fn.executable(path) == 1
end

---@param bufnr integer
---@return string
local function buffer_file(bufnr)
	return api.nvim_buf_get_name(bufnr)
end

---@param bufnr integer
---@return boolean
local function filename_matches(bufnr)
	local name = buffer_file(bufnr):lower()

	for _, pattern in ipairs(FILE_PATTERNS) do
		local suffix = pattern:match('^%*(%..+)$')
		if suffix and name:sub(-#suffix) == suffix:lower() then
			return true
		end
	end

	return false
end

---@param bufnr integer
---@return boolean
local function is_go_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end

	return FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(bufnr)
end

---@return integer?
local function current_go_buffer()
	local bufnr = api.nvim_get_current_buf()
	if is_go_buffer(bufnr) then
		return bufnr
	end

	notify('Go DAP is available only in Go buffers', vim.log.levels.ERROR)
	return nil
end

---@param bufnr integer
---@return boolean
local function update_buffer(bufnr)
	local file = buffer_file(bufnr)
	if file == '' then
		notify('Save the Go buffer before starting the debugger', vim.log.levels.ERROR)
		return false
	end

	if not vim.bo[bufnr].modified then
		return true
	end

	local ok, err = pcall(api.nvim_buf_call, bufnr, function()
		vim.cmd('silent update')
	end)

	if not ok then
		notify('Unable to save the Go buffer: ' .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param bufnr integer
---@return string
local function package_dir(bufnr)
	local file = buffer_file(bufnr)
	if file == '' then
		return fn.getcwd()
	end

	return vim.fs.dirname(file) or fn.getcwd()
end

---@param bufnr integer
---@return string
local function workspace_root(bufnr)
	local file = buffer_file(bufnr)
	if file == '' then
		return fn.getcwd()
	end

	return vim.fs.root(file, {
		'go.work',
		'go.mod',
		'.git',
	}) or package_dir(bufnr)
end

---@param args string[]
---@param run_cwd string
---@return string?
local function go_env(args, run_cwd)
	if not executable('go') then
		return nil
	end

	local command = { 'go' }
	vim.list_extend(command, args)

	local result = vim.system(command, {
		cwd = run_cwd,
		text = true,
	}):wait()

	if result.code ~= 0 or not result.stdout or result.stdout == '' then
		return nil
	end

	return vim.trim(result.stdout)
end

---@param value string
---@return boolean
local function valid_go_env_path(value)
	return value ~= '' and value ~= '/dev/null' and value ~= 'NUL'
end

---@param bufnr integer
---@return string
local function module_root(bufnr)
	local package = package_dir(bufnr)
	local gomod = go_env({ 'env', 'GOMOD' }, package)

	if type(gomod) == 'string' and valid_go_env_path(gomod) then
		return vim.fs.dirname(gomod) or workspace_root(bufnr)
	end

	return workspace_root(bufnr)
end

---@param bufnr integer
---@return string
local function work_root(bufnr)
	local package = package_dir(bufnr)
	local gowork = go_env({ 'env', 'GOWORK' }, package)

	if type(gowork) == 'string' and valid_go_env_path(gowork) then
		return vim.fs.dirname(gowork) or workspace_root(bufnr)
	end

	return workspace_root(bufnr)
end

---@param bufnr integer
---@return string
local function build_output_dir(bufnr)
	local root = workspace_root(bufnr)
	local digest = fn.sha256(root):sub(1, 16)

	return vim.fs.joinpath(fn.stdpath('cache'), 'qompass-dap', 'go', digest)
end

---@param path string
---@return boolean
local function ensure_dir(path)
	if file_exists(path) then
		return true
	end

	if fn.mkdir(path, 'p') == -1 or not file_exists(path) then
		notify('Unable to create DAP cache directory: ' .. path, vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param value string
---@return string
local function safe_filename(value)
	local result = value:gsub('[^%w._-]', '_')
	return result ~= '' and result or 'go-debug'
end

---@param bufnr integer
---@return string
local function package_binary_name(bufnr)
	local name = fn.fnamemodify(package_dir(bufnr), ':t')
	name = safe_filename(name)

	if uv.os_uname().sysname == 'Windows_NT' then
		name = name .. '.exe'
	end

	return name
end

---@param bufnr integer
---@return string
local function test_binary_name(bufnr)
	local name = safe_filename(fn.fnamemodify(package_dir(bufnr), ':t'))
	name = name .. '.test'

	if uv.os_uname().sysname == 'Windows_NT' then
		name = name .. '.exe'
	end

	return name
end

---@return string[]
local function prompt_args()
	local value = input('Args: ')
	if value == '' then
		return {}
	end

	return vim.split(value, '%s+', { trimempty = true })
end

---@return table<string, string>
local function prompt_env()
	---@type table<string, string>
	local env = {}

	while true do
		local key = input('Env key (blank to finish): ')
		if key == '' then
			break
		end

		if key:find('=', 1, true) then
			notify('Environment variable names cannot contain "="', vim.log.levels.ERROR)
		else
			env[key] = input('Env value for ' .. key .. ': ')
		end
	end

	return env
end

---@return boolean
local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end

	notify(
		('Go DAP adapter not found: %s. Install Delve and ensure it is in PATH.'):format(M.adapter.command),
		vim.log.levels.ERROR
	)
	return false
end

---@param bufnr integer
---@param config table
local function start(bufnr, config)
	if not is_go_buffer(bufnr) then
		notify('Refusing to start Go DAP outside a Go buffer', vim.log.levels.ERROR)
		return
	end

	if not update_buffer(bufnr) or not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
	config.cwd = config.cwd or workspace_root(bufnr)
	config.dlvCwd = config.dlvCwd or workspace_root(bufnr)
	debug.start(config)
end

---@param bufnr integer
---@param name string
---@param mode 'debug'|'test'
---@param program string
---@param extra? table
---@return table
local function launch_config(bufnr, name, mode, program, extra)
	local config = {
		request = 'launch',
		name = name,
		mode = mode,
		program = program,
		cwd = workspace_root(bufnr),
		dlvCwd = workspace_root(bufnr),
		args = prompt_args(),
		env = prompt_env(),
		stopOnEntry = false,
	}

	if extra then
		config = vim.tbl_extend('force', config, extra)
	end

	return config
end

---@param args string[]
---@param run_cwd string
---@return boolean
local function go_build(args, run_cwd)
	if not executable('go') then
		notify('Go toolchain not found in PATH', vim.log.levels.ERROR)
		return false
	end

	local command = { 'go' }
	vim.list_extend(command, args)
	notify('Running: ' .. table.concat(command, ' '))

	local result = vim.system(command, {
		cwd = run_cwd,
		text = true,
	}):wait()

	if result.code == 0 then
		return true
	end

	local message = result.stderr
	if not message or message == '' then
		message = result.stdout
	end
	if not message or message == '' then
		message = 'Go command failed'
	end

	notify(vim.trim(message), vim.log.levels.ERROR)
	return false
end

---@param directory string
---@return string[]
local function executable_files(directory)
	if not file_exists(directory) then
		return {}
	end

	local scanner = uv.fs_scandir(directory)
	if not scanner then
		return {}
	end

	---@type string[]
	local results = {}

	while true do
		local name, kind = uv.fs_scandir_next(scanner)
		if not name then
			break
		end

		local path = vim.fs.joinpath(directory, name)
		if kind == 'file' and is_executable(path) then
			results[#results + 1] = path
		end
	end

	table.sort(results)
	return results
end

---@param items string[]
---@param prompt string
---@return string?
local function choose_file(items, prompt)
	if #items == 0 then
		return nil
	end

	if #items == 1 then
		return items[1]
	end

	local choices = { prompt }
	for index, item in ipairs(items) do
		choices[#choices + 1] = string.format('%d. %s', index, fn.fnamemodify(item, ':t'))
	end

	local selected = fn.inputlist(choices)
	if selected < 1 or selected > #items then
		return nil
	end

	return items[selected]
end

---@param bufnr integer
---@return string?
local function resolve_executable(bufnr)
	local output_dir = build_output_dir(bufnr)
	local program = choose_file(executable_files(output_dir), 'Go executable:')

	if program then
		return program
	end

	local value = input('Path to executable: ', output_dir .. '/', 'file')

	return value ~= '' and value or nil
end

function M.run_package()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	start(bufnr, launch_config(bufnr, 'Go launch package', 'debug', package_dir(bufnr)))
end

function M.run_module_root()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	start(bufnr, launch_config(bufnr, 'Go launch module root', 'debug', module_root(bufnr)))
end

function M.run_workspace_root()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	start(bufnr, launch_config(bufnr, 'Go launch workspace root', 'debug', work_root(bufnr)))
end

function M.debug_test_file()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	local file = buffer_file(bufnr)
	if not file:match('_test%.go$') then
		notify('Current buffer is not a Go test file', vim.log.levels.ERROR)
		return
	end

	start(bufnr, launch_config(bufnr, 'Go debug tests from current file package', 'test', package_dir(bufnr)))
end

function M.debug_test_package()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	start(bufnr, launch_config(bufnr, 'Go debug package tests', 'test', package_dir(bufnr)))
end

function M.build_binary()
	local bufnr = current_go_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	local output_dir = build_output_dir(bufnr)
	if not ensure_dir(output_dir) then
		return
	end

	local default = vim.fs.joinpath(output_dir, package_binary_name(bufnr))
	local output = input('Build output: ', default, 'file')
	if output == '' then
		return
	end

	go_build({
		'build',
		'-gcflags=all=-N -l',
		'-o',
		output,
		package_dir(bufnr),
	}, workspace_root(bufnr))
end

function M.build_test_binary()
	local bufnr = current_go_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	local output_dir = build_output_dir(bufnr)
	if not ensure_dir(output_dir) then
		return
	end

	local default = vim.fs.joinpath(output_dir, test_binary_name(bufnr))
	local output = input('Test binary output: ', default, 'file')

	if output == '' then
		return
	end
	go_build({
		'test',
		'-c',
		'-gcflags=all=-N -l',
		'-o',
		output,
		package_dir(bufnr),
	}, workspace_root(bufnr))
end

function M.run_executable()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	local program = resolve_executable(bufnr)
	if not program or not is_executable(program) then
		notify('Go executable not found or is not executable', vim.log.levels.ERROR)
		return
	end

	start(bufnr, {
		request = 'launch',
		name = 'Go launch executable',
		mode = 'exec',
		program = program,
		cwd = workspace_root(bufnr),
		dlvCwd = workspace_root(bufnr),
		args = prompt_args(),
		env = prompt_env(),
		stopOnEntry = false,
	})
end

function M.debug_test_binary()
	local bufnr = current_go_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	local output_dir = build_output_dir(bufnr)
	if not ensure_dir(output_dir) then
		return
	end

	local program = vim.fs.joinpath(output_dir, test_binary_name(bufnr))

	if
		not go_build({
			'test',
			'-c',
			'-gcflags=all=-N -l',
			'-o',
			program,
			package_dir(bufnr),
		}, workspace_root(bufnr))
	then
		return
	end

	if not is_executable(program) then
		notify('Compiled Go test executable not found', vim.log.levels.ERROR)
		return
	end

	local test_filter = input('Test filter (-test.run, optional): ')
	local args = {}

	if test_filter ~= '' then
		vim.list_extend(args, {
			'-test.run',
			test_filter,
		})
	end
	vim.list_extend(args, prompt_args())
	start(bufnr, {
		request = 'launch',
		name = 'Go debug compiled test binary',
		mode = 'exec',
		program = program,
		cwd = workspace_root(bufnr),
		dlvCwd = workspace_root(bufnr),
		args = args,
		env = prompt_env(),
		stopOnEntry = false,
	})
end

function M.attach_pid()
	local bufnr = current_go_buffer()
	if not bufnr then
		return
	end

	local raw_pid = tonumber(input('PID: '))
	if not raw_pid or raw_pid < 1 or raw_pid % 1 ~= 0 then
		notify('PID must be a positive integer', vim.log.levels.ERROR)
		return
	end

	start(bufnr, {
		request = 'attach',
		name = 'Go attach PID',
		mode = 'local',
		processId = math.floor(raw_pid),
		cwd = workspace_root(bufnr),
		dlvCwd = workspace_root(bufnr),
		stopOnEntry = false,
	})
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_go_buffer(bufnr) then
		return
	end
	if vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end
	vim.b[bufnr][CONFIGURED_FLAG] = true
	api.nvim_buf_create_user_command(bufnr, 'GoDapBuild', M.build_binary, {
		desc = 'Build an unoptimized Go debug executable',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapBuildTest', M.build_test_binary, {
		desc = 'Build an unoptimized Go test executable',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapRun', M.run_package, {
		desc = 'Debug the current Go package',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapModule', M.run_module_root, {
		desc = 'Debug the current Go module root',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapWorkspace', M.run_workspace_root, {
		desc = 'Debug the current Go workspace root',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapExec', M.run_executable, {
		desc = 'Debug a prebuilt Go executable',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapTestFile', M.debug_test_file, {
		desc = 'Debug tests from the current Go test file package',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapTest', M.debug_test_package, {
		desc = 'Debug tests in the current Go package',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapTestBinary', M.debug_test_binary, {
		desc = 'Build and debug a Go test executable',
	})
	api.nvim_buf_create_user_command(bufnr, 'GoDapAttachPid', M.attach_pid, {
		desc = 'Attach Delve to a running Go process',
	})
	local function map(lhs, rhs, description)
		vim.keymap.set('n', lhs, rhs, {
			buf = bufnr,
			desc = description,
			silent = true,
		})
	end
	map('<leader>dgb', M.build_binary, 'Go DAP build')
	map('<leader>dgB', M.build_test_binary, 'Go DAP build test')
	map('<leader>dgr', M.run_package, 'Go DAP run package')
	map('<leader>dgm', M.run_module_root, 'Go DAP run module')
	map('<leader>dgw', M.run_workspace_root, 'Go DAP run workspace')
	map('<leader>dge', M.run_executable, 'Go DAP run executable')
	map('<leader>dgt', M.debug_test_package, 'Go DAP test package')
	map('<leader>dgT', M.debug_test_file, 'Go DAP test file')
	map('<leader>dgx', M.debug_test_binary, 'Go DAP test binary')
	map('<leader>dga', M.attach_pid, 'Go DAP attach PID')
end
function M.setup()
	local group = api.nvim_create_augroup('qompass.dap.go', {
		clear = true,
	})
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Go DAP for Go filetypes',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})
	api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = 'Enable Go DAP for Go files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})
	configure_buffer(api.nvim_get_current_buf())
end
return M
