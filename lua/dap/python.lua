-- ~/.config/nvim/lua/dap/python.lua
-- Qompass AI Diver Python DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv
local M = {}

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
local ROOT_MARKERS = {
	'pyproject.toml',
	'setup.py',
	'setup.cfg',
	'requirements.txt',
	'Pipfile',
	'poetry.lock',
	'uv.lock',
	'.venv',
	'venv',
	'.git',
}
local CONFIGURED_FLAG = 'qompass_python_dap_configured'
local setup_done = false
---@type table<string, boolean>
local verified_debugpy = {}
---@type table<integer, vim.SystemObj>
local pid_injection_processes = {}

M.adapter = {
	name = 'debugpy',
}

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.python',
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
---@return uv.fs_stat.result?
local function fs_stat(path)
	if path == '' then
		return nil
	end

	return uv.fs_stat(path)
end

---@param path string
---@return boolean
local function file_exists(path)
	local stat = fs_stat(path)
	return stat ~= nil and stat.type == 'file'
end

---@param value string
---@return boolean
local function safe_single_line(value)
	return not value:find('[\r\n%z]')
end

---@param bufnr integer
---@return string
local function buffer_file(bufnr)
	return api.nvim_buf_get_name(bufnr)
end

---@param bufnr integer
---@return boolean
local function filename_matches(bufnr)
	local filename = buffer_file(bufnr):lower()

	for _, pattern in ipairs(FILE_PATTERNS) do
		local suffix = pattern:match('^%*(%..+)$')
		if suffix ~= nil and filename:sub(-#suffix) == suffix:lower() then
			return true
		end
	end

	return false
end

---@param bufnr integer
---@return boolean
local function is_python_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
		return false
	end

	if buffer_file(bufnr) == '' then
		return false
	end

	return FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(bufnr)
end

---@param bufnr integer
---@return string
local function project_root(bufnr)
	local filename = buffer_file(bufnr)
	if filename == '' then
		return fn.getcwd()
	end

	local root = vim.fs.root(filename, ROOT_MARKERS)
	if root ~= nil and root ~= '' then
		return root
	end

	local parent = vim.fs.dirname(filename)
	if parent ~= nil and parent ~= '' then
		return parent
	end

	return fn.getcwd()
end

---@return integer?, string?
local function current_python_context()
	local bufnr = api.nvim_get_current_buf()

	if not is_python_buffer(bufnr) then
		notify('Python DAP is available only in Python buffers', vim.log.levels.ERROR)
		return nil, nil
	end

	return bufnr, project_root(bufnr)
end

---@param bufnr integer
---@return boolean
local function update_buffer(bufnr)
	local filename = buffer_file(bufnr)
	if filename == '' then
		notify('Save the Python buffer before debugging', vim.log.levels.ERROR)
		return false
	end

	if not vim.bo[bufnr].modified then
		return true
	end

	local ok, err = pcall(api.nvim_buf_call, bufnr, function()
		vim.cmd('silent update')
	end)

	if not ok then
		notify('Unable to save the Python buffer: ' .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@return boolean
local function is_windows()
	return uv.os_uname().sysname == 'Windows_NT'
end

---@param prefix string
---@return string?
local function environment_python(prefix)
	if prefix == '' then
		return nil
	end

	local python
	if is_windows() then
		python = vim.fs.joinpath(prefix, 'Scripts', 'python.exe')
	else
		python = vim.fs.joinpath(prefix, 'bin', 'python')
	end

	return file_exists(python) and python or nil
end

---@param root string
---@return string?
local function project_environment_python(root)
	local names = {
		'.venv',
		'venv',
		'env',
	}

	for _, name in ipairs(names) do
		local python = environment_python(vim.fs.joinpath(root, name))
		if python ~= nil then
			return python
		end
	end

	return nil
end

---@param root string
---@return string?
local function resolve_python(root)
	local python = project_environment_python(root)
	if python ~= nil then
		return python
	end

	local virtual_env = vim.env.VIRTUAL_ENV
	if virtual_env ~= nil and virtual_env ~= '' then
		python = environment_python(virtual_env)
		if python ~= nil then
			return python
		end
	end

	local conda_prefix = vim.env.CONDA_PREFIX
	if conda_prefix ~= nil and conda_prefix ~= '' then
		python = environment_python(conda_prefix)
		if python ~= nil then
			return python
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

---@param root string
---@return string?
local function ensure_python(root)
	local python = resolve_python(root)
	if python == nil then
		notify('No Python interpreter was found', vim.log.levels.ERROR)
		return nil
	end

	return python
end

---@param python string
---@param module string
---@return boolean
local function module_available(python, module)
	local result = vim.system({
		python,
		'-c',
		'import ' .. module,
	}, {
		text = true,
	}):wait(5000)

	return result.code == 0
end

---@param python string
---@return boolean
local function ensure_debugpy(python)
	if verified_debugpy[python] then
		return true
	end

	if module_available(python, 'debugpy') then
		verified_debugpy[python] = true
		return true
	end

	notify(
		string.format(
			'debugpy is not installed for %s. Install it with: %s -m pip install --upgrade debugpy',
			python,
			python
		),
		vim.log.levels.ERROR
	)
	return false
end

---@param python string
---@param module string
---@return boolean
local function ensure_module(python, module)
	if module_available(python, module) then
		return true
	end

	notify(string.format('Python module %s is not installed for %s', module, python), vim.log.levels.ERROR)
	return false
end

---@return string[]?
local function prompt_args()
	local raw = input('Arguments: ')
	if raw == '' then
		return {}
	end

	if not safe_single_line(raw) then
		notify('Arguments must be entered on one line', vim.log.levels.ERROR)
		return nil
	end

	return vim.split(raw, '%s+', {
		trimempty = true,
	})
end

---@return table<string, string>?
local function prompt_env()
	local environment = {}

	while true do
		local key = input('Environment variable (blank to finish): ')
		if key == '' then
			break
		end

		if not key:match('^[%a_][%w_]*$') then
			notify(
				'Environment variable names may contain only letters, digits, and underscores and may not begin with a digit',
				vim.log.levels.ERROR
			)
			return nil
		end

		local value = input('Value for ' .. key .. ': ')
		if not safe_single_line(value) then
			notify('Environment variable values must be entered on one line', vim.log.levels.ERROR)
			return nil
		end

		environment[key] = value
	end

	return environment
end

---@return string[]?, table<string, string>?
local function prompt_launch_inputs()
	local args = prompt_args()
	if args == nil then
		return nil, nil
	end

	local environment = prompt_env()
	if environment == nil then
		return nil, nil
	end

	return args, environment
end

---@param default? integer
---@return integer?
local function prompt_port(default)
	local value = tonumber(input('Port: ', tostring(default or 5678)))

	if value == nil or value < 1 or value > 65535 or value % 1 ~= 0 then
		return nil
	end

	return math.floor(value)
end

---@param default? string
---@return string?
local function prompt_host(default)
	local host = input('Host: ', default or '127.0.0.1')
	if host == '' then
		host = '127.0.0.1'
	end

	if not safe_single_line(host) then
		notify('Host must be entered on one line', vim.log.levels.ERROR)
		return nil
	end

	return host
end

---@param filename string
---@param root string
---@return string?
local function module_name_from_file(filename, root)
	if filename == '' or root == '' then
		return nil
	end

	local normalized_file = vim.fs.normalize(filename)
	local normalized_root = vim.fs.normalize(root)
	local prefix = normalized_root

	if prefix:sub(-1) ~= '/' then
		prefix = prefix .. '/'
	end

	local relative = normalized_file
	if normalized_file:sub(1, #prefix) == prefix then
		relative = normalized_file:sub(#prefix + 1)
	end

	relative = relative:gsub('%.pyw?$', '')
	relative = relative:gsub('^src/', '')
	relative = relative:gsub('/__init__$', '')
	relative = relative:gsub('/', '.')

	if relative == '' then
		return nil
	end

	return relative
end

---@param bufnr integer
---@param root string
---@param config table
local function start(bufnr, root, config)
	if not is_python_buffer(bufnr) then
		notify('Refusing to start Python DAP outside a Python buffer', vim.log.levels.ERROR)
		return
	end

	if not update_buffer(bufnr) then
		return
	end

	local python = ensure_python(root)
	if python == nil or not ensure_debugpy(python) then
		return
	end

	config.type = M.adapter.name
	config.python = python
	config.cwd = config.cwd or root
	debug.start(config)
end

---@param just_my_code boolean
local function launch_current_file(just_my_code)
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local filename = buffer_file(bufnr)
	if filename == '' or not file_exists(filename) then
		notify('Current Python file was not found', vim.log.levels.ERROR)
		return
	end

	local args, environment = prompt_launch_inputs()
	if args == nil or environment == nil then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = just_my_code and 'Python launch current file' or 'Python launch current file (all code)',
		program = filename,
		args = args,
		env = environment,
		console = 'integratedTerminal',
		justMyCode = just_my_code,
		stopOnEntry = false,
	})
end

function M.launch_file()
	launch_current_file(true)
end

function M.launch_file_all_code()
	launch_current_file(false)
end

function M.launch_module()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local filename = buffer_file(bufnr)
	local default_module = module_name_from_file(filename, root) or ''
	local module = input('Python module: ', default_module)

	if module == '' or not safe_single_line(module) then
		notify('Python module must be a non-empty single-line value', vim.log.levels.ERROR)
		return
	end

	local args, environment = prompt_launch_inputs()
	if args == nil or environment == nil then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Python launch module',
		module = module,
		args = args,
		env = environment,
		console = 'integratedTerminal',
		justMyCode = true,
		stopOnEntry = false,
	})
end

function M.launch_pytest()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local python = ensure_python(root)
	if python == nil or not ensure_module(python, 'pytest') then
		return
	end

	local target = buffer_file(bufnr)
	if target == '' then
		target = input('pytest target: ', root, 'file')
	end

	if target == '' or not safe_single_line(target) then
		notify('pytest target must be a non-empty single-line value', vim.log.levels.ERROR)
		return
	end

	local extra_args, environment = prompt_launch_inputs()
	if extra_args == nil or environment == nil then
		return
	end

	local args = {
		target,
	}
	vim.list_extend(args, extra_args)

	start(bufnr, root, {
		request = 'launch',
		name = 'Python pytest',
		module = 'pytest',
		args = args,
		env = environment,
		console = 'integratedTerminal',
		justMyCode = false,
		stopOnEntry = false,
	})
end

function M.launch_unittest()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local default_target = buffer_file(bufnr)
	if default_target == '' then
		default_target = root
	end

	local target = input('unittest module or path: ', default_target)
	if target == '' or not safe_single_line(target) then
		notify('unittest target must be a non-empty single-line value', vim.log.levels.ERROR)
		return
	end

	local extra_args, environment = prompt_launch_inputs()
	if extra_args == nil or environment == nil then
		return
	end

	local args = {
		target,
	}
	vim.list_extend(args, extra_args)

	start(bufnr, root, {
		request = 'launch',
		name = 'Python unittest',
		module = 'unittest',
		args = args,
		env = environment,
		console = 'integratedTerminal',
		justMyCode = false,
		stopOnEntry = false,
	})
end

function M.launch_django()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local python = ensure_python(root)
	if python == nil or not ensure_module(python, 'django') then
		return
	end

	local manage = vim.fs.joinpath(root, 'manage.py')
	if not file_exists(manage) then
		manage = input('manage.py path: ', root .. '/', 'file')
	end

	if manage == '' or not file_exists(manage) then
		notify('manage.py was not found', vim.log.levels.ERROR)
		return
	end

	local extra_args, environment = prompt_launch_inputs()
	if extra_args == nil or environment == nil then
		return
	end

	local args = {
		'runserver',
	}
	vim.list_extend(args, extra_args)

	start(bufnr, root, {
		request = 'launch',
		name = 'Python Django runserver',
		program = manage,
		args = args,
		env = environment,
		console = 'integratedTerminal',
		justMyCode = true,
		django = true,
		stopOnEntry = false,
	})
end

function M.launch_flask()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local python = ensure_python(root)
	if python == nil or not ensure_module(python, 'flask') then
		return
	end

	local app = input('FLASK_APP: ', 'app.py')
	if app == '' or not safe_single_line(app) then
		notify('FLASK_APP must be a non-empty single-line value', vim.log.levels.ERROR)
		return
	end

	local extra_args, environment = prompt_launch_inputs()
	if extra_args == nil or environment == nil then
		return
	end

	environment.FLASK_APP = app
	local args = {
		'run',
		'--no-debugger',
	}
	vim.list_extend(args, extra_args)

	start(bufnr, root, {
		request = 'launch',
		name = 'Python Flask',
		module = 'flask',
		args = args,
		env = environment,
		console = 'integratedTerminal',
		justMyCode = true,
		jinja = true,
		stopOnEntry = false,
	})
end

function M.attach_socket()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	local host = prompt_host('127.0.0.1')
	if host == nil then
		return
	end

	local port = prompt_port(5678)
	if port == nil then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return
	end

	start(bufnr, root, {
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
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	if not update_buffer(bufnr) then
		return
	end

	local python = ensure_python(root)
	if python == nil or not ensure_debugpy(python) then
		return
	end

	local raw_pid = tonumber(input('PID: '))
	if raw_pid == nil or raw_pid < 1 or raw_pid % 1 ~= 0 then
		notify('PID must be a positive integer', vim.log.levels.ERROR)
		return
	end
	local pid = math.floor(raw_pid)

	local port = prompt_port(5678)
	if port == nil then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return
	end

	local process
	process = vim.system({
		python,
		'-m',
		'debugpy',
		'--listen',
		tostring(port),
		'--pid',
		tostring(pid),
	}, {
		cwd = root,
		text = true,
	}, function(result)
		pid_injection_processes[pid] = nil

		if result.code ~= 0 then
			vim.schedule(function()
				local message = result.stderr
				if message == nil or message == '' then
					message = 'Failed to inject debugpy into the process'
				end

				notify(vim.trim(message), vim.log.levels.ERROR)
			end)
		end
	end)
	pid_injection_processes[pid] = process

	notify(string.format('Injecting debugpy into PID %d; attach will begin on 127.0.0.1:%d', pid, port))

	vim.defer_fn(function()
		if not is_python_buffer(bufnr) then
			return
		end

		start(bufnr, root, {
			request = 'attach',
			name = 'Python attach PID',
			connect = {
				host = '127.0.0.1',
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
	end, 1000)
end

function M.run_with_wait()
	local bufnr, root = current_python_context()
	if bufnr == nil or root == nil then
		return
	end

	if not update_buffer(bufnr) then
		return
	end

	local python = ensure_python(root)
	if python == nil or not ensure_debugpy(python) then
		return
	end

	local filename = buffer_file(bufnr)
	if filename == '' or not file_exists(filename) then
		notify('Current Python file was not found', vim.log.levels.ERROR)
		return
	end

	local port = prompt_port(5678)
	if port == nil then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return
	end

	local args = prompt_args()
	if args == nil then
		return
	end

	local command = {
		python,
		'-m',
		'debugpy',
		'--listen',
		tostring(port),
		'--wait-for-client',
		filename,
	}
	vim.list_extend(command, args)

	vim.cmd('botright new')
	local terminal_bufnr = api.nvim_get_current_buf()
	local job_id = fn.jobstart(command, {
		cwd = root,
		term = true,
	})

	if job_id <= 0 then
		notify('Failed to start the debugpy terminal', vim.log.levels.ERROR)
		api.nvim_buf_delete(terminal_bufnr, {
			force = true,
		})
		return
	end

	vim.bo[terminal_bufnr].bufhidden = 'wipe'
	vim.cmd.startinsert()
	notify(string.format('debugpy is waiting on 127.0.0.1:%d; use :PythonDapAttach from a Python buffer', port))
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_python_buffer(bufnr) then
		return
	end

	if vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end
	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, 'PythonDapFile', M.launch_file, {
		desc = 'Debug the current Python file',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapFileAll', M.launch_file_all_code, {
		desc = 'Debug the current Python file including library code',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapModule', M.launch_module, {
		desc = 'Debug a Python module',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapPytest', M.launch_pytest, {
		desc = 'Debug the current pytest target',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapUnitTest', M.launch_unittest, {
		desc = 'Debug a unittest target',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapDjango', M.launch_django, {
		desc = 'Debug a Django runserver process',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapFlask', M.launch_flask, {
		desc = 'Debug a Flask application',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapAttach', M.attach_socket, {
		desc = 'Attach to a debugpy socket',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapAttachPid', M.attach_pid, {
		desc = 'Inject debugpy into a PID and attach',
	})
	api.nvim_buf_create_user_command(bufnr, 'PythonDapWait', M.run_with_wait, {
		desc = 'Run the current file with debugpy waiting for a client',
	})

	---@param lhs string
	---@param rhs function
	---@param description string
	local function map(lhs, rhs, description)
		vim.keymap.set('n', lhs, rhs, {
			buffer = bufnr,
			desc = description,
			silent = true,
		})
	end

	map('<leader>dpf', M.launch_file, 'Python DAP current file')
	map('<leader>dpF', M.launch_file_all_code, 'Python DAP current file all code')
	map('<leader>dpm', M.launch_module, 'Python DAP module')
	map('<leader>dpt', M.launch_pytest, 'Python DAP pytest')
	map('<leader>dpu', M.launch_unittest, 'Python DAP unittest')
	map('<leader>dpd', M.launch_django, 'Python DAP Django')
	map('<leader>dpl', M.launch_flask, 'Python DAP Flask')
	map('<leader>dpa', M.attach_socket, 'Python DAP attach')
	map('<leader>dpA', M.attach_pid, 'Python DAP attach PID')
	map('<leader>dpw', M.run_with_wait, 'Python DAP wait')
end

function M.setup()
	if setup_done then
		configure_buffer(api.nvim_get_current_buf())
		return
	end
	setup_done = true

	local group = api.nvim_create_augroup('qompass.dap.python', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Python DAP for Python filetypes',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	api.nvim_create_autocmd({
		'BufReadPost',
		'BufNewFile',
	}, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = 'Enable Python DAP for Python files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
