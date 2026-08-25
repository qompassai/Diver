-- ~/.config/nvim/lua/dap/scala.lua
-- Qompass AI Diver Scala DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local levels = vim.log.levels
local map = vim.keymap.set
local uv = vim.uv
local M = {}
local SCALA_FILETYPES = {
	scala = true,
	sbt = true,
}
local SCALA_PATTERNS = {
	'*.scala',
	'*.sc',
	'*.sbt',
}
local RUN_TYPES = {
	run = true,
	runOrTestFile = true,
	testFile = true,
	testTarget = true,
}
local setup_done = false
---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or levels.INFO, {
		title = 'dap.scala',
	})
end
---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end

---@param bufnr integer
---@return string
local function buffer_name(bufnr)
	return api.nvim_buf_get_name(bufnr)
end

---@param bufnr integer
---@return boolean
local function is_scala_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end

	if SCALA_FILETYPES[vim.bo[bufnr].filetype] then
		return true
	end

	local name = buffer_name(bufnr):lower()
	return name:match('%.scala$') ~= nil or name:match('%.sc$') ~= nil or name:match('%.sbt$') ~= nil
end
---@return integer?
local function current_scala_buffer()
	local bufnr = api.nvim_get_current_buf()
	if is_scala_buffer(bufnr) then
		return bufnr
	end

	notify('Scala DAP is available only in Scala, Scala script, and sbt buffers', levels.ERROR)
	return nil
end
---@param bufnr integer
---@return vim.lsp.Client?
local function metals_client(bufnr)
	if not is_scala_buffer(bufnr) then
		return nil
	end
	for _, client in
		ipairs(vim.lsp.get_clients({
			bufnr = bufnr,
		}))
	do
		if client.name == 'metals' then
			return client
		end
	end

	return nil
end
---@return integer?, vim.lsp.Client?
local function current_metals_context()
	local bufnr = current_scala_buffer()
	if not bufnr then
		return nil, nil
	end
	local client = metals_client(bufnr)
	if not client then
		notify('Metals is not attached to the current Scala buffer', levels.ERROR)
		return nil, nil
	end

	return bufnr, client
end

---@param path string
---@return boolean
local function file_exists(path)
	return path ~= '' and uv.fs_stat(path) ~= nil
end

---@param bufnr integer
---@return string
local function workspace_root(bufnr)
	local name = buffer_name(bufnr)
	local start = name ~= '' and name or fn.getcwd()
	local root = vim.fs.root(start, {
		'build.sbt',
		'project.scala',
		'build.sc',
		'.bsp',
		'.metals',
		'.git',
	})
	return root or fn.getcwd()
end

local function prompt_args() ---@return string[]
	local value = input('Args: ')
	if value == '' then
		return {}
	end

	return vim.split(value, '%s+', {
		trimempty = true,
	})
end
local function prompt_jvm_options() ---@return string[]
	local value = input('JVM options: ')
	if value == '' then
		return {}
	end
	return vim.split(value, '%s+', {
		trimempty = true,
	})
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
		env[key] = input('Env value for ' .. key .. ': ')
	end
	return env
end

local function prompt_env_file() ---@return string?
	local value = input('Env file (optional): ', '', 'file')
	return value ~= '' and value or nil
end
local function prompt_build_target() ---@return string?
	local value = input('Build target (optional): ')
	return value ~= '' and value or nil
end
---@return string?
local function prompt_run_type()
	local value = input('Run type (run|runOrTestFile|testFile|testTarget): ', 'runOrTestFile')
	if value == '' then
		return 'runOrTestFile'
	end

	if not RUN_TYPES[value] then
		notify('Invalid Scala run type: ' .. value, levels.ERROR)
		return nil
	end

	return value
end

---@param client vim.lsp.Client
---@param bufnr integer
---@param command string
---@param arguments table
---@return any?, string?
local function execute_metals_command(client, bufnr, command, arguments)
	local response = client:request_sync('workspace/executeCommand', {
		command = command,
		arguments = { arguments },
	}, 30000, bufnr)
	if not response then
		return nil, 'No response from Metals'
	end
	if response.err then
		local message = type(response.err) == 'table' and response.err.message or nil
		return nil, message or tostring(response.err)
	end
	return response.result, nil
end
---@param result any
---@return string?
local function adapter_uri(result)
	if type(result) == 'string' and result ~= '' then
		return result
	end

	if type(result) == 'table' and type(result.uri) == 'string' and result.uri ~= '' then
		return result.uri
	end

	return nil
end

---@param bufnr integer
---@param uri string
---@param name string
local function start_uri_adapter(bufnr, uri, name)
	debug.start({
		type = 'scala',
		request = 'attach',
		name = name,
		uri = uri,
		cwd = workspace_root(bufnr),
		sourceLanguages = { 'scala' },
	})
end

---@param bufnr integer
---@param client vim.lsp.Client
---@param params table
---@param name string
local function start_metals_debug(bufnr, client, params, name)
	local result, err = execute_metals_command(client, bufnr, 'debug-adapter-start', params)

	if err then
		notify(err, vim.log.levels.ERROR)
		return
	end

	local uri = adapter_uri(result)
	if not uri then
		notify('Metals did not return a debug adapter URI', levels.ERROR)
		return
	end

	start_uri_adapter(bufnr, uri, name)
end

---@param lines string[]
---@param filetype string
local function show_scratch_buffer(lines, filetype)
	vim.cmd('botright new')
	local bufnr = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].bufhidden = 'wipe'
	vim.bo[bufnr].buftype = 'nofile'
	vim.bo[bufnr].filetype = filetype
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = false
end

function M.debug_main()
	local bufnr, client = current_metals_context()
	if not bufnr or not client then
		return
	end

	local main_class = input('Main class: ')
	if main_class == '' then
		notify('Main class is required', vim.log.levels.ERROR)
		return
	end
	start_metals_debug(bufnr, client, {
		mainClass = main_class,
		buildTarget = prompt_build_target(),
		args = prompt_args(),
		jvmOptions = prompt_jvm_options(),
		env = prompt_env(),
		envFile = prompt_env_file(),
	}, 'Scala debug main')
end

function M.debug_test_class()
	local bufnr, client = current_metals_context()
	if not bufnr or not client then
		return
	end

	local test_class = input('Test class: ')
	if test_class == '' then
		notify('Test class is required', vim.log.levels.ERROR)
		return
	end

	start_metals_debug(bufnr, client, {
		testClass = test_class,
		buildTarget = prompt_build_target(),
		args = prompt_args(),
		jvmOptions = prompt_jvm_options(),
		env = prompt_env(),
		envFile = prompt_env_file(),
	}, 'Scala debug test class')
end

function M.debug_current_file()
	local bufnr, client = current_metals_context()
	if not bufnr or not client then
		return
	end

	local file = buffer_name(bufnr)
	if not file_exists(file) then
		notify('Current Scala file not found', vim.log.levels.ERROR)
		return
	end

	local run_type = prompt_run_type()
	if not run_type then
		return
	end

	start_metals_debug(bufnr, client, {
		path = vim.uri_from_fname(file),
		runType = run_type,
		args = prompt_args(),
		jvmOptions = prompt_jvm_options(),
		env = prompt_env(),
		envFile = prompt_env_file(),
	}, 'Scala debug current file')
end

function M.run_command_for_file()
	local bufnr, client = current_metals_context()
	if not bufnr or not client then
		return
	end

	local file = buffer_name(bufnr)
	if not file_exists(file) then
		notify('Current Scala file not found', vim.log.levels.ERROR)
		return
	end

	local run_type = prompt_run_type()
	if not run_type then
		return
	end

	local result, err = execute_metals_command(client, bufnr, 'discover-jvm-run-command', {
		path = vim.uri_from_fname(file),
		runType = run_type,
		args = prompt_args(),
		jvmOptions = prompt_jvm_options(),
		env = prompt_env(),
		envFile = prompt_env_file(),
	})

	if err then
		notify(err, vim.log.levels.ERROR)
		return
	end

	show_scratch_buffer(vim.split(vim.inspect(result), '\n', { plain = true }), 'lua')
end
function M.attach_jdwp()
	local bufnr, client = current_metals_context()
	if not bufnr or not client then
		return
	end
	local host = input('Host: ', '127.0.0.1')
	if host == '' then
		host = '127.0.0.1'
	end
	local raw_port = tonumber(input('Port: ', '5005'))
	if not raw_port or raw_port < 1 or raw_port > 65535 or raw_port % 1 ~= 0 then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return
	end
	start_metals_debug(bufnr, client, {
		hostName = host,
		port = math.floor(raw_port),
		buildTarget = prompt_build_target(),
	}, 'Scala attach JDWP')
end
function M.sbt_debug_hint()
	if not current_scala_buffer() then
		return
	end
	show_scratch_buffer({
		'Start sbt with a debug port, for example:',
		'sbt -jvm-debug 5005',
		'',
		'Then use :ScalaDapAttach to attach through Metals.',
	}, 'markdown')
end

function M.trace_files_hint()
	if not current_scala_buffer() then
		return
	end

	local home = vim.env.HOME or uv.os_homedir() or ''
	local cache = home .. '/.cache/metals'
	show_scratch_buffer({
		'Metals DAP trace files on Linux:',
		cache .. '/dap-server.trace.json',
		cache .. '/dap-client.trace.json',
	}, 'markdown')
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_scala_buffer(bufnr) then
		return
	end

	if vim.b[bufnr].qompass_scala_dap_configured then
		return
	end
	vim.b[bufnr].qompass_scala_dap_configured = true

	api.nvim_buf_create_user_command(bufnr, 'ScalaDapMain', M.debug_main, {
		desc = 'Debug Scala main class through buffer-local Metals',
	})
	api.nvim_buf_create_user_command(bufnr, 'ScalaDapTest', M.debug_test_class, {
		desc = 'Debug Scala test class through buffer-local Metals',
	})
	api.nvim_buf_create_user_command(bufnr, 'ScalaDapFile', M.debug_current_file, {
		desc = 'Debug current Scala file through buffer-local Metals',
	})
	api.nvim_buf_create_user_command(bufnr, 'ScalaRunCommand', M.run_command_for_file, {
		desc = 'Discover the JVM command for the current Scala file',
	})
	api.nvim_buf_create_user_command(bufnr, 'ScalaDapAttach', M.attach_jdwp, {
		desc = 'Attach to a JVM through buffer-local Metals',
	})
	api.nvim_buf_create_user_command(bufnr, 'ScalaSbtDebugHint', M.sbt_debug_hint, {
		desc = 'Show the sbt debug attach hint',
	})
	api.nvim_buf_create_user_command(bufnr, 'ScalaDapTraceHint', M.trace_files_hint, {
		desc = 'Show Metals DAP trace file paths',
	})

	local map_opts = function(description)
		return {
			buffer = bufnr,
			desc = description,
			silent = true,
		}
	end
	map('n', '<leader>sm', M.debug_main, map_opts('Scala DAP main'))
	vim.keymap.set('n', '<leader>st', M.debug_test_class, map_opts('Scala DAP test'))
	vim.keymap.set('n', '<leader>sf', M.debug_current_file, map_opts('Scala DAP file'))
	vim.keymap.set('n', '<leader>sr', M.run_command_for_file, map_opts('Scala run command'))
	vim.keymap.set('n', '<leader>sa', M.attach_jdwp, map_opts('Scala attach JDWP'))
	vim.keymap.set('n', '<leader>sh', M.sbt_debug_hint, map_opts('Scala sbt debug hint'))
	vim.keymap.set('n', '<leader>sx', M.trace_files_hint, map_opts('Scala DAP trace hint'))
end

function M.setup()
	if setup_done then
		configure_buffer(api.nvim_get_current_buf())
		return
	end
	setup_done = true

	local group = api.nvim_create_augroup('qompass.dap.scala', { clear = true })

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = { 'scala', 'sbt' },
		desc = 'Enable Scala DAP for Scala filetypes',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})
	api.nvim_create_autocmd({
		'BufReadPost',
		'BufNewFile',
	}, {
		group = group,
		pattern = SCALA_PATTERNS,
		desc = 'Enable Scala DAP for Scala file extensions',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})
	configure_buffer(api.nvim_get_current_buf())
end

return M
