-- ~/.config/nvim/lua/dap/lldb.lua
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local map = vim.keymap.set
local FILETYPES = {
	c = true,
	cpp = true,
	objc = true,
	objcpp = true,
}
local FILETYPE_PATTERNS = {
	'c',
	'cpp',
	'objc',
	'objcpp',
}
local FILE_PATTERNS = { '*.c', '*.h', '*.cc', '*.cpp', '*.cxx', '*.m', '*.mm' }
local M = {}
M.adapter = {
	name = 'lldb-dap',
	command = 'lldb-dap',
}
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.lldb' })
end

local function executable(cmd)
	return fn.executable(cmd) == 1
end

local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end

local function cwd()
	return fn.getcwd()
end

local function current_file()
	return api.nvim_buf_get_name(0)
end

local function file_exists(path)
	return type(path) == 'string' and path ~= '' and uv.fs_stat(path) ~= nil
end

local function is_dir(path)
	local stat = uv.fs_stat(path)
	return stat and stat.type == 'directory' or false
end

local function path_join(...)
	return table.concat({ ... }, '/')
end

local function workspace_root()
	local file = current_file()
	local start = file ~= '' and file or cwd()

	local root = vim.fs.root(start, {
		'Cargo.toml',
		'compile_commands.json',
		'Makefile',
		'CMakeLists.txt',
		'.git',
	})

	return root or cwd()
end

local function ensure_adapter()
	if executable(M.adapter.command) then
		return M.adapter.command
	end

	if fn.has('mac') == 1 and executable('xcrun') then
		local result = vim.system({
			'xcrun',
			'-f',
			'lldb-dap',
		}, {
			text = true,
		}):wait()
		if result.code == 0 and result.stdout and result.stdout ~= '' then
			return vim.trim(result.stdout)
		end
	end
	notify('lldb-dap not found in PATH. Install LLVM lldb and ensure lldb-dap is available.', vim.log.levels.ERROR)
	return nil
end
local function start(config)
	local adapter_cmd = ensure_adapter()
	if not adapter_cmd then
		return
	end

	config.type = M.adapter.name
	config.adapter = {
		type = 'executable',
		command = adapter_cmd,
		args = {},
	}

	debug.start(config)
end

local function prompt_args()
	local raw = input('Args: ', '')
	if raw == '' then
		return {}
	end
	return vim.split(raw, '%s+', {
		trimempty = true,
	})
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

local function prompt_program(default)
	local program = input('Program: ', default or (workspace_root() .. '/'), 'file')
	if program == '' then
		return nil
	end
	return program
end

local function cargo_debug_target_guess()
	local root = workspace_root()
	local cargo = path_join(root, 'Cargo.toml')
	if not file_exists(cargo) then
		return nil
	end

	local package_name
	for _, line in ipairs(fn.readfile(cargo)) do
		local name = line:match('^%s*name%s*=%s*"([^"]+)"')
		if name then
			package_name = name
			break
		end
	end

	if not package_name then
		return nil
	end

	package_name = package_name:gsub('%-', '_')
	local target = path_join(root, 'target', 'debug', package_name)
	if file_exists(target) then
		return target
	end

	return target
end

local function c_binary_guess()
	local root = workspace_root()
	local candidates = {
		path_join(root, 'a.out'),
		path_join(root, 'build', 'a.out'),
		path_join(root, 'bin', fn.fnamemodify(root, ':t')),
		path_join(root, 'build', fn.fnamemodify(root, ':t')),
	}

	for _, candidate in ipairs(candidates) do
		if file_exists(candidate) then
			return candidate
		end
	end

	return root .. '/'
end

local function default_program_guess()
	local rust_guess = cargo_debug_target_guess()
	if rust_guess then
		return rust_guess
	end
	return c_binary_guess()
end

function M.launch()
	local program = prompt_program(default_program_guess())
	if not program or program == '' then
		notify('Program is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'LLDB launch',
		program = program,
		args = prompt_args(),
		cwd = workspace_root(),
		env = prompt_env(),
		stopOnEntry = false,
	})
end

function M.launch_current_file_binary()
	local file = current_file()
	if file == '' then
		notify('No current file', vim.log.levels.ERROR)
		return
	end

	local stem = fn.fnamemodify(file, ':t:r')
	local root = workspace_root()
	local candidates = {
		path_join(root, 'target', 'debug', stem),
		path_join(root, 'build', stem),
		path_join(root, stem),
	}

	local picked
	for _, candidate in ipairs(candidates) do
		if file_exists(candidate) then
			picked = candidate
			break
		end
	end

	picked = prompt_program(picked or (root .. '/' .. stem))
	if not picked or picked == '' then
		notify('Program is required', vim.log.levels.ERROR)
		return
	end
	start({
		request = 'launch',
		name = 'LLDB launch current binary',
		program = picked,
		args = prompt_args(),
		cwd = workspace_root(),
		env = prompt_env(),
		stopOnEntry = false,
	})
end
function M.attach_pid()
	local pid = tonumber(input('PID: ', ''))
	if not pid then
		notify('Invalid PID', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'LLDB attach pid',
		pid = pid,
		cwd = workspace_root(),
	})
end

function M.attach_program()
	local program = prompt_program(default_program_guess())
	if not program or program == '' then
		notify('Program path is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'LLDB attach program',
		program = program,
		cwd = workspace_root(),
		waitFor = true,
	})
end

function M.open_core()
	local program = prompt_program(default_program_guess())
	if not program or program == '' then
		notify('Program path is required', vim.log.levels.ERROR)
		return
	end

	local core = input('Core file: ', workspace_root() .. '/', 'file')
	if core == '' then
		notify('Core file is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'LLDB core file',
		program = program,
		coreFile = core,
		cwd = workspace_root(),
	})
end

function M.rust_launch()
	local program = prompt_program(cargo_debug_target_guess() or default_program_guess())
	if not program or program == '' then
		notify('Rust debug target is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Rust LLDB launch',
		program = program,
		args = prompt_args(),
		cwd = workspace_root(),
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'rust' },
	})
end

function M.help()
	local lines = {
		'lldb-dap examples',
		'',
		':LldbDapLaunch        - launch an executable',
		':LldbDapAttachPid     - attach to an existing process by PID',
		':LldbDapAttachProgram - wait for and attach to a program path',
		':LldbDapCore          - inspect a core dump',
		':LldbDapRust          - Rust-friendly launch helper',
		'',
		'Install notes:',
		'- Arch Linux: pacman -S lldb',
		'- macOS Homebrew: brew install llvm',
		'- macOS Xcode 16+: xcrun lldb-dap',
	}
	vim.cmd('new')
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = 'wipe'
	vim.bo[buf].filetype = 'markdown'
end
function M.setup()
	api.nvim_create_user_command('LldbDapLaunch', M.launch, {
		desc = 'Launch executable with lldb-dap',
	})
	api.nvim_create_user_command('LldbDapLaunchFile', M.launch_current_file_binary, {
		desc = 'Launch guessed binary for current file',
	})
	api.nvim_create_user_command('LldbDapAttachPid', M.attach_pid, {
		desc = 'Attach to process ID with lldb-dap',
	})
	api.nvim_create_user_command('LldbDapAttachProgram', M.attach_program, {
		desc = 'Attach to program path with lldb-dap',
	})
	api.nvim_create_user_command('LldbDapCore', M.open_core, {
		desc = 'Open core file with lldb-dap',
	})
	api.nvim_create_user_command('LldbDapRust', M.rust_launch, {
		desc = 'Launch Rust target with lldb-dap',
	})
	api.nvim_create_user_command('LldbDapHelp', M.help, {
		desc = 'Show lldb-dap usage help',
	})
	map('n', '<leader>dl', M.launch, { desc = 'LLDB DAP launch' })
	map('n', '<leader>df', M.launch_current_file_binary, { desc = 'LLDB DAP launch file' })
	map('n', '<leader>dp', M.attach_pid, { desc = 'LLDB DAP attach pid' })
	map('n', '<leader>dP', M.attach_program, { desc = 'LLDB DAP attach program' })
	map('n', '<leader>dc', M.open_core, { desc = 'LLDB DAP core file' })
	map('n', '<leader>dr', M.rust_launch, { desc = 'LLDB DAP rust' })
	map('n', '<leader>dh', M.help, { desc = 'LLDB DAP help' })
end

return M
