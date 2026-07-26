-- ~/.config/nvim/lua/dap/rust.lua

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local RUST_FILETYPES = {
	rust = true,
}
local RUST_PATTERNS = {
	'*.rs',
}
local M = {}
M.adapter = {
	name = 'codelldb',
	command = 'codelldb',
}
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.rust' })
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
		'Cargo.toml',
		'rust-project.json',
		'.git',
	})

	return root or cwd()
end

local function cargo_toml_path()
	return workspace_root() .. '/Cargo.toml'
end

local function cargo_package_name()
	local path = cargo_toml_path()
	if not file_exists(path) then
		return nil
	end

	for _, line in ipairs(fn.readfile(path)) do
		local name = line:match('^%s*name%s*=%s*"([^"]+)"')
		if name then
			return name
		end
	end

	return nil
end

local function cargo_metadata_target_dir()
	local root = workspace_root()
	if not executable('cargo') then
		return root .. '/target'
	end

	local result = vim.system({
		'cargo',
		'metadata',
		'--format-version',
		'1',
		'--no-deps',
	}, {
		cwd = root,
		text = true,
	}):wait()

	if result.code ~= 0 or not result.stdout or result.stdout == '' then
		return root .. '/target'
	end

	local ok, decoded = pcall(vim.json.decode, result.stdout)
	if not ok or type(decoded) ~= 'table' then
		return root .. '/target'
	end

	return decoded.target_directory or (root .. '/target')
end

local function target_debug_dir()
	return cargo_metadata_target_dir() .. '/debug'
end

local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end

	notify(
		('Rust DAP adapter not found: %s Install codelldb and ensure it is available in PATH.'):format(
			M.adapter.command
		),
		vim.log.levels.ERROR
	)
	return false
end

local function start(config)
	if not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
	debug.start(config)
end

local function cargo_build(args)
	local root = workspace_root()

	if not executable('cargo') then
		notify('cargo not found in PATH', vim.log.levels.ERROR)
		return false
	end

	local cmd = { 'cargo' }
	vim.list_extend(cmd, args)

	notify('Running: ' .. table.concat(cmd, ' '))

	local result = vim.system(cmd, {
		cwd = root,
		text = true,
	}):wait()

	if result.code ~= 0 then
		local stderr = (result.stderr and result.stderr ~= '') and result.stderr or 'cargo command failed'
		notify(stderr, vim.log.levels.ERROR)
		return false
	end

	return true
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

local function candidate_bins()
	local dir = target_debug_dir()
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

		local path = dir .. '/' .. name
		if
			typ == 'file'
			and is_executable(path)
			and not name:match('%.d$')
			and not name:match('%.rlib$')
			and not name:match('%.rmeta$')
			and not name:match('%.[oa]$')
			and not name:match('^build%-script')
		then
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
	local bins = candidate_bins()
	if #bins == 1 then
		return bins[1]
	end
	if #bins > 1 then
		local picked = choose(bins, 'Rust executable:')
		if picked then
			return picked
		end
	end

	local pkg = cargo_package_name()
	local default = target_debug_dir() .. '/'
	if pkg then
		default = target_debug_dir() .. '/' .. pkg
	end

	local program = input('Path to executable: ', default, 'file')
	if program == '' then
		return nil
	end
	return program
end

function M.build()
	cargo_build({ 'build' })
end

function M.build_release()
	cargo_build({ 'build', '--release' })
end

function M.run_binary()
	if not cargo_build({ 'build' }) then
		return
	end

	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Rust executable not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Rust launch binary',
		program = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'rust' },
	})
end

function M.run_current_package()
	local pkg = cargo_package_name()
	if not pkg then
		notify('Could not resolve package name from Cargo.toml', vim.log.levels.ERROR)
		return
	end
	if not cargo_build({ 'build', '--package', pkg }) then
		return
	end
	local program = target_debug_dir() .. '/' .. pkg
	if vim.uv.os_uname().sysname == 'Windows_NT' then
		program = program .. '.exe'
	end

	if not file_exists(program) then
		program = resolve_program()
	end

	if not program or not file_exists(program) then
		notify('Rust package executable not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Rust launch package',
		program = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'rust' },
	})
end

function M.debug_test()
	local root = workspace_root()
	local target_name = input('Test target (blank for current package): ', cargo_package_name() or '')
	local build_args = { 'test', '--no-run' }

	if target_name ~= '' then
		vim.list_extend(build_args, { '--package', target_name })
	end

	if not cargo_build(build_args) then
		return
	end

	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Compiled test executable not found', vim.log.levels.ERROR)
		return
	end

	local test_filter = input('Test filter: ', '')
	local args = {}
	if test_filter ~= '' then
		args[#args + 1] = test_filter
	end
	vim.list_extend(args, prompt_args())

	start({
		request = 'launch',
		name = 'Rust debug test',
		program = program,
		cwd = root,
		args = args,
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'rust' },
	})
end

function M.attach_pid()
	local raw_pid = input('PID: ', '')
	local pid = tonumber(raw_pid)

	if not pid or pid < 1 or pid % 1 ~= 0 then
		notify('Invalid PID', vim.log.levels.ERROR)
		return
	end

	pid = math.floor(pid)

	local program_input = input('Path to executable (optional): ', target_debug_dir() .. '/', 'file')

	---@type string?
	local program = program_input ~= '' and program_input or nil

	start({
		request = 'attach',
		name = 'Rust attach PID',
		pid = pid,
		program = program,
		cwd = workspace_root(),
		sourceLanguages = { 'rust' },
	})
end

function M.attach_executable()
	local program = input('Path to executable: ', target_debug_dir() .. '/', 'file')
	if program == '' or not file_exists(program) then
		notify('Executable not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'Rust attach executable',
		program = program,
		cwd = workspace_root(),
		sourceLanguages = { 'rust' },
	})
end

function M.setup()
	api.nvim_create_user_command('RustDapBuild', M.build, {
		desc = 'cargo build',
	})

	api.nvim_create_user_command('RustDapBuildRelease', M.build_release, {
		desc = 'cargo build --release',
	})

	api.nvim_create_user_command('RustDapRun', M.run_binary, {
		desc = 'Build and debug Rust binary',
	})

	api.nvim_create_user_command('RustDapPackage', M.run_current_package, {
		desc = 'Build and debug current Rust package',
	})

	api.nvim_create_user_command('RustDapTest', M.debug_test, {
		desc = 'Build tests and debug Rust test binary',
	})

	api.nvim_create_user_command('RustDapAttachPid', M.attach_pid, {
		desc = 'Attach debugger to running Rust PID',
	})

	api.nvim_create_user_command('RustDapAttachExe', M.attach_executable, {
		desc = 'Attach debugger to Rust executable',
	})

	vim.keymap.set('n', '<leader>rb', M.build, {
		desc = 'Rust DAP build',
	})
	vim.keymap.set('n', '<leader>rB', M.build_release, {
		desc = 'Rust DAP build release',
	})
	vim.keymap.set('n', '<leader>rd', M.run_binary, {
		desc = 'Rust DAP run',
	})
	vim.keymap.set('n', '<leader>rp', M.run_current_package, {
		desc = 'Rust DAP package',
	})
	vim.keymap.set('n', '<leader>rt', M.debug_test, {
		desc = 'Rust DAP test',
	})
	vim.keymap.set('n', '<leader>ra', M.attach_pid, { desc = 'Rust DAP attach pid' })
	vim.keymap.set('n', '<leader>re', M.attach_executable, {
		desc = 'Rust DAP attach exe',
	})
end

return M
