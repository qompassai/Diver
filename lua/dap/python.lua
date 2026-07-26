-- ~/.config/nvim/lua/dap/python.lua

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local FILETYPES = {
	python = true,
}
local FILETYPE_PATTERNS = {
	'python',
}
local FILE_PATTERNS = {
	'*.py',
	'*.pyw',
}
local M = {}
M.adapter = {
	name = 'debugpy',
}
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, {
		title = 'dap.python',
	})
end
local function cwd()
	return fn.getcwd()
end
local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end
local function executable(cmd)
	return fn.executable(cmd) == 1
end
local function file_exists(path)
	return type(path) == 'string' and path ~= '' and uv.fs_stat(path) ~= nil
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
		'pyproject.toml',
		'setup.py',
		'setup.cfg',
		'requirements.txt',
		'.venv',
		'venv',
		'.git',
	})

	return root or cwd()
end

local function path_join(...)
	return table.concat({ ... }, '/')
end

local function is_windows()
	return uv.os_uname().sysname == 'Windows_NT'
end

local function venv_python(root)
	if is_windows() then
		local candidates = {
			path_join(root, '.venv', 'Scripts', 'python.exe'),
			path_join(root, 'venv', 'Scripts', 'python.exe'),
		}
		for _, path in ipairs(candidates) do
			if file_exists(path) then
				return path
			end
		end
	else
		local candidates = {
			path_join(root, '.venv', 'bin', 'python'),
			path_join(root, 'venv', 'bin', 'python'),
		}
		for _, path in ipairs(candidates) do
			if file_exists(path) then
				return path
			end
		end
	end
	return nil
end

local function resolve_python()
	local root = workspace_root()
	local from_venv = venv_python(root)
	if from_venv then
		return from_venv
	end

	local env_python = vim.env.VIRTUAL_ENV
	if env_python and env_python ~= '' then
		if is_windows() then
			local path = path_join(env_python, 'Scripts', 'python.exe')
			if file_exists(path) then
				return path
			end
		else
			local path = path_join(env_python, 'bin', 'python')
			if file_exists(path) then
				return path
			end
		end
	end

	if executable('python3') then
		return 'python3'
	end
	if executable('python') then
		return 'python'
	end

	return nil
end

local function ensure_python()
	local py = resolve_python()
	if not py then
		notify('No Python interpreter found', vim.log.levels.ERROR)
		return nil
	end
	return py
end

local function ensure_debugpy(py)
	local result = vim.system({
		py,
		'-c',
		'import debugpy',
	}, { text = true }):wait()
	if result.code == 0 then
		return true
	end
	notify(
		('debugpy is not installed for %s Install it with: %s -m pip install --upgrade debugpy'):format(py, py),
		vim.log.levels.ERROR
	)
	return false
end

local function start(config)
	local py = ensure_python()
	if not py then
		return
	end
	if not ensure_debugpy(py) then
		return
	end

	config.type = M.adapter.name
	config.python = py
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

local function prompt_port(default)
	local port = tonumber(input('Port: ', tostring(default or 5678)))
	if not port then
		return nil
	end
	return port
end

local function prompt_host(default)
	local host = input('Host: ', default or '127.0.0.1')
	if host == '' then
		return '127.0.0.1'
	end
	return host
end

local function module_name_from_file(file, root)
	if file == '' or root == '' then
		return nil
	end

	local rel = fn.fnamemodify(file, ':.')
	if rel == file then
		rel = file:gsub('^' .. vim.pesc(root .. '/'), '')
	end

	rel = rel:gsub('%.py$', '')
	rel = rel:gsub('/', '.')
	rel = rel:gsub('\\', '.')
	rel = rel:gsub('^src%.', '')

	if rel == '' then
		return nil
	end

	return rel
end

function M.launch_file()
	local file = current_file()
	if file == '' or not file_exists(file) then
		notify('Current Python file not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Python launch file',
		program = file,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		justMyCode = true,
		stopOnEntry = false,
	})
end

function M.launch_file_all_code()
	local file = current_file()
	if file == '' or not file_exists(file) then
		notify('Current Python file not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Python launch file (all code)',
		program = file,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		justMyCode = false,
		stopOnEntry = false,
	})
end

function M.launch_module()
	local file = current_file()
	local root = workspace_root()
	local default_module = module_name_from_file(file, root) or ''
	local module = input('Python module: ', default_module)

	if module == '' then
		notify('No module specified', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Python launch module',
		module = module,
		cwd = root,
		args = prompt_args(),
		env = prompt_env(),
		console = 'integratedTerminal',
		justMyCode = true,
		stopOnEntry = false,
	})
end

function M.launch_pytest()
	local root = workspace_root()
	local target = current_file()

	if target == '' then
		target = input('pytest target: ', root, 'file')
	end
	if target == '' then
		notify('No pytest target specified', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Python pytest',
		module = 'pytest',
		cwd = root,
		args = vim.list_extend({ target }, prompt_args()),
		env = prompt_env(),
		console = 'integratedTerminal',
		justMyCode = false,
		stopOnEntry = false,
	})
end

function M.launch_unittest()
	local root = workspace_root()
	local target = input('unittest module or path: ', current_file() ~= '' and current_file() or root)

	if target == '' then
		notify('No unittest target specified', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Python unittest',
		module = 'unittest',
		cwd = root,
		args = vim.list_extend({ target }, prompt_args()),
		env = prompt_env(),
		console = 'integratedTerminal',
		justMyCode = false,
		stopOnEntry = false,
	})
end

function M.launch_django()
	local root = workspace_root()
	local manage = path_join(root, 'manage.py')

	if not file_exists(manage) then
		manage = input('manage.py path: ', root .. '/', 'file')
	end
	if manage == '' or not file_exists(manage) then
		notify('manage.py not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Python Django runserver',
		program = manage,
		cwd = root,
		args = vim.list_extend({ 'runserver' }, prompt_args()),
		env = prompt_env(),
		console = 'integratedTerminal',
		justMyCode = true,
		django = true,
		stopOnEntry = false,
	})
end

function M.launch_flask()
	local root = workspace_root()
	local app = input('FLASK_APP: ', 'app.py')

	if app == '' then
		notify('FLASK_APP is required', vim.log.levels.ERROR)
		return
	end

	local env = prompt_env()
	env.FLASK_APP = app

	start({
		request = 'launch',
		name = 'Python Flask',
		module = 'flask',
		cwd = root,
		args = vim.list_extend({ 'run', '--no-debugger' }, prompt_args()),
		env = env,
		console = 'integratedTerminal',
		justMyCode = true,
		jinja = true,
		stopOnEntry = false,
	})
end

function M.attach_socket()
	local root = workspace_root()
	local host = prompt_host('127.0.0.1')
	local port = prompt_port(5678)

	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'Python attach socket',
		connect = {
			host = host,
			port = port,
		},
		pathMappings = {
			{
				localRoot = root,
				remoteRoot = '.',
			},
		},
		justMyCode = false,
	})
end

function M.attach_pid()
	local py = ensure_python()
	if not py then
		return
	end
	if not ensure_debugpy(py) then
		return
	end

	local pid = tonumber(input('PID: ', ''))
	if not pid then
		notify('Invalid PID', vim.log.levels.ERROR)
		return
	end

	local port = prompt_port(5678)
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	local result = vim.system({
		py,
		'-m',
		'debugpy',
		'--listen',
		tostring(port),
		'--pid',
		tostring(pid),
	}, {
		text = true,
	}):wait()

	if result.code ~= 0 then
		local stderr = (result.stderr and result.stderr ~= '') and result.stderr
			or 'Failed to inject debugpy into process'
		notify(stderr, vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'Python attach PID',
		connect = {
			host = '127.0.0.1',
			port = port,
		},
		pathMappings = {
			{
				localRoot = workspace_root(),
				remoteRoot = '.',
			},
		},
		justMyCode = false,
	})
end

function M.run_with_wait()
	local py = ensure_python()
	if not py then
		return
	end
	if not ensure_debugpy(py) then
		return
	end

	local file = current_file()
	if file == '' or not file_exists(file) then
		notify('Current Python file not found', vim.log.levels.ERROR)
		return
	end

	local port = prompt_port(5678)
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	local cmd = {
		py,
		'-m',
		'debugpy',
		'--listen',
		tostring(port),
		'--wait-for-client',
		file,
	}
	vim.list_extend(cmd, prompt_args())

	vim.cmd('botright new')

	local job_id = vim.fn.jobstart(cmd, {
		cwd = workspace_root(),
		term = true,
	})

	if job_id <= 0 then
		notify('Failed to start debugpy terminal')
		return
	end

	vim.cmd.startinsert()
	notify(('Started debugpy wait-for-client on port %d'):format(port))
end
function M.setup()
	api.nvim_create_user_command('PythonDapFile', M.launch_file, {
		desc = 'Debug current Python file',
	})
	api.nvim_create_user_command('PythonDapFileAll', M.launch_file_all_code, {
		desc = 'Debug current Python file with library code',
	})
	api.nvim_create_user_command('PythonDapModule', M.launch_module, {
		desc = 'Debug Python module',
	})
	api.nvim_create_user_command('PythonDapPytest', M.launch_pytest, {
		desc = 'Debug pytest target',
	})
	api.nvim_create_user_command('PythonDapUnitTest', M.launch_unittest, {
		desc = 'Debug unittest target',
	})
	api.nvim_create_user_command('PythonDapDjango', M.launch_django, {
		desc = 'Debug Django runserver',
	})

	api.nvim_create_user_command('PythonDapFlask', M.launch_flask, {
		desc = 'Debug Flask app',
	})

	api.nvim_create_user_command('PythonDapAttach', M.attach_socket, {
		desc = 'Attach to debugpy socket',
	})

	api.nvim_create_user_command('PythonDapAttachPid', M.attach_pid, {
		desc = 'Inject debugpy into PID and attach',
	})

	api.nvim_create_user_command('PythonDapWait', M.run_with_wait, {
		desc = 'Run current file with debugpy --wait-for-client',
	})
	vim.keymap.set('n', '<leader>pf', M.launch_file, { desc = 'Python DAP file' })
	vim.keymap.set('n', '<leader>pF', M.launch_file_all_code, { desc = 'Python DAP file all code' })
	vim.keymap.set('n', '<leader>pm', M.launch_module, { desc = 'Python DAP module' })
	vim.keymap.set('n', '<leader>pt', M.launch_pytest, { desc = 'Python DAP pytest' })
	vim.keymap.set('n', '<leader>pu', M.launch_unittest, { desc = 'Python DAP unittest' })
	vim.keymap.set('n', '<leader>pd', M.launch_django, { desc = 'Python DAP django' })
	vim.keymap.set('n', '<leader>pl', M.launch_flask, { desc = 'Python DAP flask' })
	vim.keymap.set('n', '<leader>pa', M.attach_socket, { desc = 'Python DAP attach' })
	vim.keymap.set('n', '<leader>pA', M.attach_pid, { desc = 'Python DAP attach pid' })
	vim.keymap.set('n', '<leader>pw', M.run_with_wait, { desc = 'Python DAP wait' })
end

return M
