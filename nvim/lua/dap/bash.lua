-- ~/.config/nvim/lua/dap/bash.lua
-- Qompass AI Diver Bash DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ---------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv
local M = {}
local FILETYPES = {
	bash = true,
	sh = true,
}

local FILETYPE_PATTERNS = {
	'bash',
	'sh',
}

local FILE_PATTERNS = {
	'*.bash',
	'*.sh',
}

local CONFIGURED_FLAG = 'qompass_bash_dap_configured'
local MASON_PACKAGE = vim.fs.joinpath(fn.stdpath('data'), 'mason', 'packages', 'bash-debug-adapter')
local MASON_WRAPPER = vim.fs.joinpath(MASON_PACKAGE, 'bash-debug-adapter')
local MASON_EXTENSION = vim.fs.joinpath(MASON_PACKAGE, 'extension')
local MASON_BASHDB_DIR = vim.fs.joinpath(MASON_EXTENSION, 'bashdb_dir')
local MASON_BASHDB = vim.fs.joinpath(MASON_BASHDB_DIR, 'bashdb')

M.adapter = {
	name = 'bashdb',
	command = MASON_WRAPPER,
	args = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.bash',
	})
end

---@param command string
---@return boolean
local function executable(command)
	return command ~= '' and fn.executable(command) == 1
end

---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end

---@param path string
---@return uv.fs_stat.result?
local function fs_stat(path)
	if path == '' then
		return nil
	end

	return uv.fs_stat(path)
end

---@param path string
---@return boolean
local function is_file(path)
	local stat = fs_stat(path)
	return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_dir(path)
	local stat = fs_stat(path)
	return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return boolean
local function is_executable_file(path)
	return is_file(path) and executable(path)
end

---@param command string
---@param candidates? string[]
---@return string?
local function resolve_executable(command, candidates)
	local from_path = fn.exepath(command)
	if from_path ~= '' and is_executable_file(from_path) then
		return from_path
	end

	for _, candidate in ipairs(candidates or {}) do
		if is_executable_file(candidate) then
			return candidate
		end
	end

	return nil
end

---@param bufnr integer
---@return string
local function buffer_file(bufnr)
	return api.nvim_buf_get_name(bufnr)
end

---@param path string
---@return string?
local function read_shebang(path)
	if not is_file(path) then
		return nil
	end

	local ok, lines = pcall(fn.readfile, path, '', 1)
	if not ok or type(lines) ~= 'table' or type(lines[1]) ~= 'string' then
		return nil
	end

	return lines[1]:match('^#!%s*(.+)$')
end

---@param path string
---@return boolean
local function has_bash_shebang(path)
	local shebang = read_shebang(path)
	return shebang ~= nil and shebang:lower():match('%f[%w]bash%f[^%w_]') ~= nil
end

---@param path string
---@return boolean
local function has_foreign_shell_shebang(path)
	local shebang = read_shebang(path)
	if not shebang then
		return false
	end

	shebang = shebang:lower()
	for _, shell in ipairs({ 'dash', 'fish', 'ksh', 'mksh', 'sh', 'zsh' }) do
		if shebang:match('%f[%w]' .. shell .. '%f[^%w_]') then
			return true
		end
	end

	return false
end

---@param path string
---@return boolean
local function filename_matches(path)
	local name = path:lower()

	for _, pattern in ipairs(FILE_PATTERNS) do
		local suffix = pattern:match('^%*(%..+)$')
		if suffix and name:sub(-#suffix) == suffix:lower() then
			return true
		end
	end

	return false
end

---@param path string
---@return boolean
local function is_bash_script(path)
	if path == '' or not is_file(path) then
		return false
	end

	if has_foreign_shell_shebang(path) then
		return false
	end

	return filename_matches(path) or has_bash_shebang(path)
end

---@param bufnr integer
---@return boolean
local function is_bash_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end

	local path = buffer_file(bufnr)
	if path == '' or has_foreign_shell_shebang(path) then
		return false
	end

	return FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(path) or has_bash_shebang(path)
end

---@return integer?
local function current_bash_buffer()
	local bufnr = api.nvim_get_current_buf()
	if is_bash_buffer(bufnr) then
		return bufnr
	end

	notify('Bash DAP is available only in Bash buffers', vim.log.levels.ERROR)
	return nil
end

---@param bufnr integer
---@return boolean
local function update_buffer(bufnr)
	local path = buffer_file(bufnr)
	if path == '' then
		notify('Save the Bash buffer before starting the debugger', vim.log.levels.ERROR)
		return false
	end

	if not vim.bo[bufnr].modified then
		return true
	end

	local ok, err = pcall(api.nvim_buf_call, bufnr, function()
		vim.cmd('silent update')
	end)
	if not ok then
		notify('Unable to save the Bash buffer: ' .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param bufnr integer
---@return string
local function workspace_root(bufnr)
	local path = buffer_file(bufnr)
	if path == '' then
		return fn.getcwd()
	end

	return vim.fs.root(path, {
		'.git',
		'.envrc',
		'flake.nix',
		'shell.nix',
		'Makefile',
	}) or vim.fs.dirname(path) or fn.getcwd()
end

---@param value string
---@return string
local function absolute_path(value)
	return vim.fs.normalize(fn.fnamemodify(value, ':p'))
end

---@param value string
---@return boolean
local function valid_single_line(value)
	return not value:find('[\r\n%z]')
end

---@return string?
local function prompt_args_string()
	local value = input('Arguments (shell-style string): ', '')
	if not valid_single_line(value) then
		notify('Arguments must be a single line without NUL bytes', vim.log.levels.ERROR)
		return nil
	end

	return value
end

---@return table<string, string>?
local function prompt_env()
	local env = {}

	while true do
		local key = input('Environment key (blank to finish): ', '')
		if key == '' then
			return env
		end

		if not key:match('^[%a_][%w_]*$') then
			notify('Invalid environment variable name: ' .. key, vim.log.levels.ERROR)
			return nil
		end

		local value = input('Value for ' .. key .. ': ', '')
		if not valid_single_line(value) then
			notify('Environment values must be single-line strings', vim.log.levels.ERROR)
			return nil
		end

		env[key] = value
	end
end

---@param items string[]
---@param prompt string
---@return string?
local function choose(items, prompt)
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

	local choice = fn.inputlist(choices)
	if choice < 1 or choice > #items then
		return nil
	end

	return items[choice]
end

---@param directory string
---@return string[]
local function candidate_scripts(directory)
	if not is_dir(directory) then
		return {}
	end

	local scanner = uv.fs_scandir(directory)
	if not scanner then
		return {}
	end

	local scripts = {}
	while true do
		local name, kind = uv.fs_scandir_next(scanner)
		if not name then
			break
		end

		if kind == 'file' or kind == 'link' then
			local path = vim.fs.joinpath(directory, name)
			if is_bash_script(path) then
				scripts[#scripts + 1] = path
			end
		end
	end

	table.sort(scripts)
	return scripts
end

---@param bufnr integer
---@return string?
local function resolve_program(bufnr)
	local path = buffer_file(bufnr)
	if path ~= '' and vim.bo[bufnr].modified and not update_buffer(bufnr) then
		return nil
	end

	if is_bash_script(path) then
		return path
	end

	local scripts = candidate_scripts(workspace_root(bufnr))
	local selected = choose(scripts, 'Bash script:')
	if selected then
		return selected
	end

	local value = input('Path to Bash script: ', workspace_root(bufnr) .. '/', 'file')
	if value == '' then
		return nil
	end

	local program = absolute_path(value)
	if not is_bash_script(program) then
		notify('Selected file is not a readable Bash script', vim.log.levels.ERROR)
		return nil
	end

	return program
end

---@return boolean
local function resolve_adapter()
	local wrappers = {
		MASON_WRAPPER,
		vim.fs.joinpath(MASON_EXTENSION, 'bash-debug-adapter'),
	}

	for _, wrapper in ipairs(wrappers) do
		if is_executable_file(wrapper) then
			M.adapter.command = wrapper
			M.adapter.args = {}
			return true
		end
	end

	local path_wrapper = resolve_executable('bash-debug-adapter')
	if path_wrapper then
		M.adapter.command = path_wrapper
		M.adapter.args = {}
		return true
	end

	local node = resolve_executable('node', {
		'/usr/bin/node',
		'/usr/local/bin/node',
	})
	local javascript_candidates = {
		vim.fs.joinpath(MASON_EXTENSION, 'out', 'bashDebug.js'),
		vim.fs.joinpath(MASON_PACKAGE, 'out', 'bashDebug.js'),
	}

	if node then
		for _, javascript in ipairs(javascript_candidates) do
			if is_file(javascript) then
				M.adapter.command = node
				M.adapter.args = { javascript }
				return true
			end
		end
	end

	local value = input('Path to bash-debug-adapter executable or bashDebug.js: ', MASON_PACKAGE .. '/', 'file')
	if value == '' then
		return false
	end

	local adapter = absolute_path(value)
	if adapter:match('%.js$') then
		if not node or not is_file(adapter) then
			notify('A readable adapter JavaScript file and Node.js are required', vim.log.levels.ERROR)
			return false
		end

		M.adapter.command = node
		M.adapter.args = { adapter }
		return true
	end

	if not is_executable_file(adapter) then
		notify('The Bash DAP adapter is not executable: ' .. adapter, vim.log.levels.ERROR)
		return false
	end

	M.adapter.command = adapter
	M.adapter.args = {}
	return true
end

---@return string?, string?
local function resolve_bashdb()
	if is_executable_file(MASON_BASHDB) and is_dir(MASON_BASHDB_DIR) then
		return MASON_BASHDB, MASON_BASHDB_DIR
	end

	local executable_path = resolve_executable('bashdb', {
		'/usr/bin/bashdb',
		'/usr/local/bin/bashdb',
	})
	if executable_path then
		for _, directory in ipairs({
			'/usr/share/bashdb',
			'/usr/local/share/bashdb',
		}) do
			if is_dir(directory) then
				return executable_path, directory
			end
		end
	end

	local bashdb = input('Path to bashdb: ', executable_path or MASON_BASHDB, 'file')
	if bashdb == '' then
		return nil, nil
	end
	bashdb = absolute_path(bashdb)
	if not is_executable_file(bashdb) then
		notify('bashdb is not executable: ' .. bashdb, vim.log.levels.ERROR)
		return nil, nil
	end

	local default_library = executable_path == bashdb and '/usr/share/bashdb' or vim.fs.dirname(bashdb) or ''
	local directory = input('Path to bashdb library directory: ', default_library, 'dir')
	if directory == '' then
		return nil, nil
	end
	directory = absolute_path(directory)
	if not is_dir(directory) then
		notify('bashdb library directory was not found: ' .. directory, vim.log.levels.ERROR)
		return nil, nil
	end

	return bashdb, directory
end

---@class BashDapRuntime
---@field bash string
---@field bashdb string
---@field bashdb_dir string
---@field cat string
---@field mkfifo string
---@field pkill string

---@return BashDapRuntime?
local function resolve_runtime()
	if not resolve_adapter() then
		notify(
			'Bash DAP adapter not found. Install Mason bash-debug-adapter or rogalmic/bash-debug.',
			vim.log.levels.ERROR
		)
		return nil
	end

	local node = resolve_executable('node', {
		'/usr/bin/node',
		'/usr/local/bin/node',
	})
	if not node then
		notify('Node.js is required by bash-debug-adapter', vim.log.levels.ERROR)
		return nil
	end

	local bash = resolve_executable('bash', {
		'/usr/bin/bash',
		'/bin/bash',
		'/usr/local/bin/bash',
	})
	local cat = resolve_executable('cat', {
		'/usr/bin/cat',
		'/bin/cat',
	})
	local mkfifo = resolve_executable('mkfifo', {
		'/usr/bin/mkfifo',
		'/bin/mkfifo',
	})
	local pkill = resolve_executable('pkill', {
		'/usr/bin/pkill',
		'/bin/pkill',
		'/usr/local/bin/pkill',
	})
	local bashdb, bashdb_dir = resolve_bashdb()

	local missing = {}
	if not bash then
		missing[#missing + 1] = 'bash'
	end
	if not cat then
		missing[#missing + 1] = 'cat'
	end
	if not mkfifo then
		missing[#missing + 1] = 'mkfifo'
	end
	if not pkill then
		missing[#missing + 1] = 'pkill'
	end
	if not bashdb or not bashdb_dir then
		missing[#missing + 1] = 'bashdb'
	end

	if #missing > 0 then
		notify('Missing Bash debugger runtime tools: ' .. table.concat(missing, ', '), vim.log.levels.ERROR)
		return nil
	end
	if not bash or not cat or not mkfifo or not pkill or not bashdb or not bashdb_dir then
		return nil
	end

	return {
		bash = bash,
		bashdb = bashdb,
		bashdb_dir = bashdb_dir,
		cat = cat,
		mkfifo = mkfifo,
		pkill = pkill,
	}
end

---@param bufnr integer
---@param config table
local function start(bufnr, config)
	if not is_bash_buffer(bufnr) then
		notify('Bash DAP is available only in Bash buffers', vim.log.levels.ERROR)
		return
	end
	if not update_buffer(bufnr) then
		return
	end

	local runtime = resolve_runtime()
	if not runtime then
		return
	end

	config.type = M.adapter.name
	config.pathBash = runtime.bash
	config.pathBashdb = runtime.bashdb
	config.pathBashdbLib = runtime.bashdb_dir
	config.pathCat = runtime.cat
	config.pathMkfifo = runtime.mkfifo
	config.pathPkill = runtime.pkill
	config.showDebugOutput = config.showDebugOutput == true
	config.trace = config.trace == true
	config.terminalKind = config.terminalKind or 'debugConsole'

	debug.start(config)
end

---@param bufnr integer
---@param program string
---@param name string
---@param adapter_trace? boolean
local function launch(bufnr, program, name, adapter_trace)
	if not is_bash_script(program) then
		notify('Bash script not found: ' .. program, vim.log.levels.ERROR)
		return
	end

	local args_string = prompt_args_string()
	if args_string == nil then
		return
	end

	local env = prompt_env()
	if env == nil then
		return
	end

	start(bufnr, {
		request = 'launch',
		name = name,
		program = program,
		cwd = workspace_root(bufnr),
		argsString = args_string,
		env = env,
		showDebugOutput = adapter_trace == true,
		trace = adapter_trace == true,
	})
end

function M.run_script()
	local bufnr = current_bash_buffer()
	if not bufnr then
		return
	end

	local program = resolve_program(bufnr)
	if program then
		launch(bufnr, program, 'Bash launch script')
	end
end

function M.run_file()
	local bufnr = current_bash_buffer()
	if not bufnr then
		return
	end
	if not update_buffer(bufnr) then
		return
	end

	local program = buffer_file(bufnr)
	if not is_bash_script(program) then
		notify('Current file is not a readable Bash script', vim.log.levels.ERROR)
		return
	end

	launch(bufnr, program, 'Bash launch current file')
end

function M.run_selection()
	local bufnr = current_bash_buffer()
	if not bufnr then
		return
	end

	local program = choose(candidate_scripts(workspace_root(bufnr)), 'Bash script:')
	if program then
		launch(bufnr, program, 'Bash launch selected script')
	end
end

function M.run_prompt()
	local bufnr = current_bash_buffer()
	if not bufnr then
		return
	end

	local value = input('Path to Bash script: ', workspace_root(bufnr) .. '/', 'file')
	if value == '' then
		return
	end

	local program = absolute_path(value)
	launch(bufnr, program, 'Bash launch prompted script')
end

function M.run_with_adapter_trace()
	local bufnr = current_bash_buffer()
	if not bufnr then
		return
	end

	local program = resolve_program(bufnr)
	if program then
		launch(bufnr, program, 'Bash launch with DAP trace', true)
	end
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_bash_buffer(bufnr) or vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end

	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, 'BashDapRun', M.run_script, {
		desc = 'Debug a Bash script',
	})
	api.nvim_buf_create_user_command(bufnr, 'BashDapFile', M.run_file, {
		desc = 'Debug the current Bash file',
	})
	api.nvim_buf_create_user_command(bufnr, 'BashDapSelect', M.run_selection, {
		desc = 'Select and debug a Bash script',
	})
	api.nvim_buf_create_user_command(bufnr, 'BashDapPrompt', M.run_prompt, {
		desc = 'Prompt for a Bash script to debug',
	})
	api.nvim_buf_create_user_command(bufnr, 'BashDapTrace', M.run_with_adapter_trace, {
		desc = 'Debug Bash with DAP adapter tracing',
	})

	local map_options = function(description)
		return {
			buffer = bufnr,
			desc = description,
			silent = true,
		}
	end

	vim.keymap.set('n', '<leader>dbr', M.run_script, map_options('Bash DAP run'))
	vim.keymap.set('n', '<leader>dbf', M.run_file, map_options('Bash DAP current file'))
	vim.keymap.set('n', '<leader>dbs', M.run_selection, map_options('Bash DAP select'))
	vim.keymap.set('n', '<leader>dbp', M.run_prompt, map_options('Bash DAP prompt'))
	vim.keymap.set('n', '<leader>dbt', M.run_with_adapter_trace, map_options('Bash DAP adapter trace'))
end

local setup_done = false

function M.setup()
	if setup_done then
		return
	end
	setup_done = true

	local group = api.nvim_create_augroup('QompassBashDap', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Bash DAP for Bash filetypes',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = 'Enable Bash DAP for Bash file extensions',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
