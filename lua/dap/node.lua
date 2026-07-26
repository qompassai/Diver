-- ~/.config/nvim/lua/dap/node.lua
-- Node.js DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local FILETYPES = {
	javascript = true,
	javascriptreact = true,
	typescript = true,
	typescriptreact = true,
}
local FILETYPE_PATTERNS = {
	'javascript',
	'javascriptreact',
	'typescript',
	'typescriptreact',
}
local FILE_PATTERNS = {
	'*.js',
	'*.jsx',
	'*.mjs',
	'*.cjs',
	'*.ts',
	'*.tsx',
}
local M = {}

M.adapter = {
	name = 'pwa-node',
	command = 'node',
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.node' })
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

local function is_dir(path)
	local stat = type(path) == 'string' and path ~= '' and uv.fs_stat(path) or nil
	return stat and stat.type == 'directory' or false
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
		'package.json',
		'tsconfig.json',
		'jsconfig.json',
		'.git',
	})

	return root or cwd()
end

local function joinpath(...)
	return vim.fs.joinpath(...)
end

local function data_path()
	return fn.stdpath('data')
end

local function js_debug_paths()
	local mason_root = joinpath(data_path(), 'mason', 'packages', 'js-debug-adapter')
	return {
		joinpath(mason_root, 'js-debug', 'src', 'dapDebugServer.js'),
		joinpath(mason_root, 'js-debug', 'out', 'src', 'dapDebugServer.js'),
	}
end

local function resolve_js_debug_server()
	for _, path in ipairs(js_debug_paths()) do
		if file_exists(path) then
			return path
		end
	end

	local default = joinpath(data_path(), 'mason', 'packages', 'js-debug-adapter')
	local picked = input('Path to dapDebugServer.js: ', default .. '/', 'file')
	if picked == '' then
		return nil
	end
	return picked
end

local function ensure_adapter()
	if not executable(M.adapter.command) then
		notify('node not found in PATH', vim.log.levels.ERROR)
		return false
	end

	local server = resolve_js_debug_server()
	if not server or not file_exists(server) then
		notify(
			'js-debug adapter not found. Install js-debug-adapter and ensure dapDebugServer.js is available.',
			vim.log.levels.ERROR
		)
		return false
	end

	M.adapter.args = { server, '${port}', '127.0.0.1' }
	return true
end

local function start(config)
	if not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
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

local function package_json_path()
	return joinpath(workspace_root(), 'package.json')
end

local function read_json(path)
	if not file_exists(path) then
		return nil
	end

	local lines = fn.readfile(path)
	if not lines or vim.tbl_isempty(lines) then
		return nil
	end

	local ok, decoded = pcall(vim.json.decode, table.concat(lines, ''))
	if not ok or type(decoded) ~= 'table' then
		return nil
	end

	return decoded
end

local function package_json()
	return read_json(package_json_path())
end
local function package_scripts()
	local pkg = package_json()
	if type(pkg) ~= 'table' or type(pkg.scripts) ~= 'table' then
		return {}
	end
	return pkg.scripts
end

local function script_names()
	local names = {}
	for name, _ in pairs(package_scripts()) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function choose(items, prompt)
	if #items == 0 then
		return nil
	end

	local choices = { prompt or 'Select:' }
	for i, item in ipairs(items) do
		choices[#choices + 1] = string.format('%d. %s', i, item)
	end

	local idx = fn.inputlist(choices)
	if idx < 1 or idx > #items then
		return nil
	end

	return items[idx]
end

local function candidate_programs(dir)
	if not is_dir(dir) then
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
		if
			typ == 'file'
			and (
				name:match('%.js$')
				or name:match('%.cjs$')
				or name:match('%.mjs$')
				or name:match('%.ts$')
				or name:match('%.cts$')
				or name:match('%.mts$')
			)
		then
			items[#items + 1] = path
		end
	end
	table.sort(items)
	return items
end
local function resolve_program()
	local file = current_file()
	if file ~= '' and file:match('%.[cm]?[jt]s$') then
		return file
	end
	local root = workspace_root()
	local bins = candidate_programs(root)
	if #bins == 1 then
		return bins[1]
	end
	if #bins > 1 then
		local short = {}
		local map = {}
		for _, item in ipairs(bins) do
			local rel = item:gsub('^' .. vim.pesc(root .. '/'), '')
			short[#short + 1] = rel
			map[rel] = item
		end
		local picked = choose(short, 'Node program:')
		if picked then
			return map[picked]
		end
	end

	local program = input('Path to program: ', root .. '/', 'file')
	if program == '' then
		return nil
	end
	return program
end

local function has_local_bin(name)
	return file_exists(joinpath(workspace_root(), 'node_modules', '.bin', name))
end

local function detect_runtime()
	if has_local_bin('tsx') then
		return 'tsx'
	end
	if has_local_bin('ts-node') then
		return 'ts-node'
	end
	return 'node'
end

local function default_skip_files()
	return {
		'<node_internals>/**',
		joinpath(workspace_root(), 'node_modules', '**'),
	}
end

function M.run_file()
	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Program not found', vim.log.levels.ERROR)
		return
	end

	local runtime = detect_runtime()
	local ext = fn.fnamemodify(program, ':e')
	local runtime_executable = runtime
	local runtime_args = {}

	if runtime == 'node' and (ext == 'ts' or ext == 'cts' or ext == 'mts') then
		notify('TypeScript file detected but no tsx/ts-node runtime found', vim.log.levels.WARN)
	end

	start({
		request = 'launch',
		name = 'Node launch file',
		program = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		internalConsoleOptions = 'neverOpen',
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
		runtimeExecutable = runtime_executable,
		runtimeArgs = runtime_args,
	})
end
function M.run_npm_script()
	local scripts = script_names()
	if #scripts == 0 then
		notify('No package.json scripts found', vim.log.levels.ERROR)
		return
	end
	local script = choose(scripts, 'npm script:')
	if not script then
		return
	end
	start({
		request = 'launch',
		name = 'Node launch npm script',
		cwd = workspace_root(),
		runtimeExecutable = 'npm',
		runtimeArgs = {
			'run',
			script,
			'--',
		},
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		internalConsoleOptions = 'neverOpen',
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
	})
end

function M.attach_port()
	local port = tonumber(input('Port: ', '9229'))
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'Node attach port',
		address = '127.0.0.1',
		port = port,
		cwd = workspace_root(),
		restart = true,
		continueOnAttach = true,
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
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
		name = 'Node attach PID',
		processId = tostring(pid),
		cwd = workspace_root(),
		continueOnAttach = true,
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
	})
end

function M.attach_next_dev()
	local port = tonumber(input('Next inspect port: ', '9229'))
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'Node attach Next dev',
		address = '127.0.0.1',
		port = port,
		cwd = workspace_root(),
		restart = true,
		continueOnAttach = true,
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
	})
end

function M.run_jest()
	local jest = joinpath(workspace_root(), 'node_modules', 'jest', 'bin', 'jest.js')
	if not file_exists(jest) then
		notify('jest not found in node_modules', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Node debug Jest',
		runtimeExecutable = 'node',
		runtimeArgs = { jest, '--runInBand' },
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		internalConsoleOptions = 'neverOpen',
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
	})
end

function M.run_mocha()
	local mocha = joinpath(workspace_root(), 'node_modules', 'mocha', 'bin', 'mocha.js')
	if not file_exists(mocha) then
		notify('mocha not found in node_modules', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Node debug Mocha',
		runtimeExecutable = 'node',
		runtimeArgs = { mocha },
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		internalConsoleOptions = 'neverOpen',
		skipFiles = default_skip_files(),
		sourceMaps = true,
		smartStep = true,
	})
end

function M.setup()
	api.nvim_create_user_command('NodeDapRun', M.run_file, {
		desc = 'Debug Node file',
	})

	api.nvim_create_user_command('NodeDapScript', M.run_npm_script, {
		desc = 'Debug npm script',
	})

	api.nvim_create_user_command('NodeDapAttach', M.attach_port, {
		desc = 'Attach to Node inspect port',
	})

	api.nvim_create_user_command('NodeDapAttachPid', M.attach_pid, {
		desc = 'Attach to Node process ID',
	})

	api.nvim_create_user_command('NodeDapNext', M.attach_next_dev, {
		desc = 'Attach to Next.js dev server',
	})

	api.nvim_create_user_command('NodeDapJest', M.run_jest, {
		desc = 'Debug Jest tests',
	})

	api.nvim_create_user_command('NodeDapMocha', M.run_mocha, {
		desc = 'Debug Mocha tests',
	})

	vim.keymap.set('n', '<leader>nd', M.run_file, {
		desc = 'Node DAP run',
	})
	vim.keymap.set('n', '<leader>ns', M.run_npm_script, {
		desc = 'Node DAP script',
	})
	vim.keymap.set('n', '<leader>na', M.attach_port, {
		desc = 'Node DAP attach port',
	})
	vim.keymap.set('n', '<leader>nA', M.attach_pid, { desc = 'Node DAP attach pid' })
	vim.keymap.set('n', '<leader>nn', M.attach_next_dev, { desc = 'Node DAP next' })
	vim.keymap.set('n', '<leader>nj', M.run_jest, { desc = 'Node DAP jest' })
	vim.keymap.set('n', '<leader>nm', M.run_mocha, { desc = 'Node DAP mocha' })
end

return M
