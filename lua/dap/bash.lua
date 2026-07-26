local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local FILETYPES = { sh = true, bash = true }
local FILETYPE_PATTERNS = { 'sh', 'bash' }
local FILE_PATTERNS = { '*.sh', '*.bash' }
local M = {}
M.adapter = {
	name = 'bashdb',
	command = nil,
}
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.bash' })
end
local function executable(cmd)
	return fn.executable(cmd) == 1
end

local function cwd()
	return fn.getcwd()
end

local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end

local function file_exists(path)
	return type(path) == 'string' and path ~= '' and uv.fs_stat(path) ~= nil
end

local function is_executable(path)
	return file_exists(path) and fn.executable(path) == 1
end

local function current_file()
	return api.nvim_buf_get_name(0)
end

local function workspace_root()
	local file = current_file()
	if file == '' then
		return cwd()
	end

	local root = vim.fs.root(file, {
		'.git',
		'.envrc',
		'shell.nix',
		'flake.nix',
		'package.json',
		'Makefile',
	})

	return root or cwd()
end

local function joinpath(...)
	return vim.fs.joinpath(...)
end

local function data_path()
	return fn.stdpath('data')
end

local function mason_pkg_root()
	return joinpath(data_path(), 'mason', 'packages', 'bash-debug-adapter')
end

local function default_adapter_command()
	local root = mason_pkg_root()
	local candidates = {
		joinpath(root, 'bash-debug-adapter'),
		joinpath(root, 'extension', 'out', 'bashDebug.js'),
	}

	for _, path in ipairs(candidates) do
		if file_exists(path) then
			return path
		end
	end

	return nil
end

local function default_bashdb_dir()
	return joinpath(mason_pkg_root(), 'extension', 'bashdb_dir')
end

local function default_bashdb()
	return joinpath(default_bashdb_dir(), 'bashdb')
end

local function first_executable(paths)
	for _, path in ipairs(paths) do
		if executable(path) then
			return path
		end
	end
	return nil
end

local function resolve_path_or_input(prompt_text, default)
	local value = input(prompt_text, default or '', 'file')
	if value == '' then
		return nil
	end
	return value
end

local function resolve_adapter_command()
	if M.adapter.command and file_exists(M.adapter.command) then
		return M.adapter.command
	end

	local found = default_adapter_command()
	if found then
		M.adapter.command = found
		return found
	end

	return resolve_path_or_input('Path to bash-debug-adapter: ', mason_pkg_root() .. '/', 'file')
end

local function resolve_bash()
	local env_bash = vim.env.SHELL
	if env_bash and env_bash ~= '' and executable(env_bash) then
		return env_bash
	end

	return first_executable({
		'/usr/bin/bash',
		'/bin/bash',
		'/usr/local/bin/bash',
	})
end

local function resolve_cat()
	return first_executable({
		'/usr/bin/cat',
		'/bin/cat',
		'cat',
	})
end

local function resolve_mkfifo()
	return first_executable({
		'/usr/bin/mkfifo',
		'/bin/mkfifo',
		'mkfifo',
	})
end

local function resolve_pkill()
	return first_executable({
		'/usr/bin/pkill',
		'/bin/pkill',
		'/usr/local/bin/pkill',
		'pkill',
	})
end
local function ensure_adapter()
	local adapter_cmd = resolve_adapter_command()
	if not adapter_cmd or not file_exists(adapter_cmd) then
		notify(
			'Bash DAP adapter not found. Install rogalmic Bash Debug / bash-debug-adapter, or set the adapter path manually.',
			vim.log.levels.ERROR
		)
		return false
	end
	M.adapter.command = adapter_cmd

	local bashdb = default_bashdb()
	local bashdb_dir = default_bashdb_dir()
	local bash = resolve_bash()
	local cat = resolve_cat()
	local mkfifo = resolve_mkfifo()
	local pkill = resolve_pkill()

	if not file_exists(bashdb) then
		notify('bashdb not found: ' .. bashdb, vim.log.levels.ERROR)
		return false
	end
	if not file_exists(bashdb_dir) then
		notify('bashdb lib dir not found: ' .. bashdb_dir, vim.log.levels.ERROR)
		return false
	end
	if not bash then
		notify('bash not found in PATH', vim.log.levels.ERROR)
		return false
	end
	if not cat then
		notify('cat not found in PATH', vim.log.levels.ERROR)
		return false
	end
	if not mkfifo then
		notify('mkfifo not found in PATH', vim.log.levels.ERROR)
		return false
	end
	if not pkill then
		notify('pkill not found in PATH', vim.log.levels.ERROR)
		return false
	end
	return true
end
local function start(config)
	if not ensure_adapter() then
		return
	end
	config.type = M.adapter.name
	config.pathBashdb = default_bashdb()
	config.pathBashdbLib = default_bashdb_dir()
	config.pathBash = resolve_bash()
	config.pathCat = resolve_cat()
	config.pathMkfifo = resolve_mkfifo()
	config.pathPkill = resolve_pkill()
	config.showDebugOutput = config.showDebugOutput ~= false
	config.trace = config.trace ~= false
	config.terminalKind = config.terminalKind or 'integrated'

	debug.start(config)
end

local function prompt_args()
	local raw = input('Args: ', '')
	if raw == '' then
		return {}
	end
	return vim.split(raw, '%s+', { trimempty = true })
end
local function prompt_env()
	local env = {}
	while true do
		local key = input('Env key (blank to finish): ', '')
		if key == '' then
			break
		end
		env[key] = input('Env value for ' .. key .. ': ', '')
	end
	return env
end

local function candidate_scripts(dir)
	if not file_exists(dir) then
		return {}
	end

	local scanner = uv.fs_scandir(dir)
	if not scanner then
		return {}
	end

	local items = {}
	while true do
		local name, typ = uv.fs_scandir_next(scanner)
		if not name then
			break
		end
		local path = joinpath(dir, name)
		if typ == 'file' and (name:match('%.sh$') or is_executable(path)) then
			items[#items + 1] = path
		end
	end
	table.sort(items)
	return items
end
local function choose(items, prompt)
	if #items == 0 then
		return nil
	end
	local choices = { prompt or 'Select:' }
	for i, item in ipairs(items) do
		choices[#choices + 1] = string.format('%d. %s', i, fn.fnamemodify(item, ':t'))
	end
	local idx = fn.inputlist(choices)
	if idx < 1 or idx > #items then
		return nil
	end
	return items[idx]
end
local function resolve_program()
	local file = current_file()
	if file ~= '' and file:match('%.sh$') then
		return file
	end
	local scripts = candidate_scripts(workspace_root())
	if #scripts == 1 then
		return scripts[1]
	end
	if #scripts > 1 then
		local picked = choose(scripts, 'Bash script:')
		if picked then
			return picked
		end
	end

	local program = input('Path to script: ', workspace_root() .. '/', 'file')
	if program == '' then
		return nil
	end
	return program
end

local function shellcheck()
	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Script not found', vim.log.levels.ERROR)
		return
	end

	if not executable('shellcheck') then
		notify('shellcheck not found in PATH', vim.log.levels.ERROR)
		return
	end

	local result = vim.system({ 'shellcheck', program }, {
		cwd = workspace_root(),
		text = true,
	}):wait()

	if result.code == 0 then
		notify('shellcheck: no issues found')
		return
	end

	local msg = (result.stdout and result.stdout ~= '') and result.stdout
		or ((result.stderr and result.stderr ~= '') and result.stderr)
		or 'shellcheck reported issues'
	notify(msg, vim.log.levels.WARN)
end

function M.run_script()
	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Script not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Bash launch script',
		program = program,
		file = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
	})
end

function M.run_file()
	local program = current_file()
	if program == '' or not file_exists(program) then
		notify('Current file not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Bash launch current file',
		program = program,
		file = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
	})
end

function M.run_with_xtrace()
	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Script not found', vim.log.levels.ERROR)
		return
	end

	local args = { '-x' }
	vim.list_extend(args, prompt_args())

	start({
		request = 'launch',
		name = 'Bash launch script (-x)',
		program = program,
		file = program,
		cwd = workspace_root(),
		args = args,
		env = prompt_env(),
	})
end

function M.run_selection()
	local scripts = candidate_scripts(workspace_root())
	local picked = choose(scripts, 'Bash script:')
	if not picked or not file_exists(picked) then
		notify('Script not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Bash launch selected script',
		program = picked,
		file = picked,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
	})
end

function M.setup()
	api.nvim_create_user_command('BashDapRun', M.run_script, {
		desc = 'Debug bash script',
	})

	api.nvim_create_user_command('BashDapFile', M.run_file, {
		desc = 'Debug current bash file',
	})

	api.nvim_create_user_command('BashDapSelect', M.run_selection, {
		desc = 'Select and debug bash script',
	})

	api.nvim_create_user_command('BashDapTrace', M.run_with_xtrace, {
		desc = 'Debug bash script with -x',
	})

	api.nvim_create_user_command('BashDapCheck', shellcheck, {
		desc = 'Run shellcheck on bash script',
	})

	vim.keymap.set('n', '<leader>bd', M.run_script, { desc = 'Bash DAP run' })
	vim.keymap.set('n', '<leader>bf', M.run_file, { desc = 'Bash DAP file' })
	vim.keymap.set('n', '<leader>bs', M.run_selection, { desc = 'Bash DAP select' })
	vim.keymap.set('n', '<leader>bx', M.run_with_xtrace, { desc = 'Bash DAP trace' })
	vim.keymap.set('n', '<leader>bc', shellcheck, { desc = 'Bash DAP check' })
end
return M
