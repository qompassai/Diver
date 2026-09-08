-- ~/.config/nvim/lua/dap/node.lua
-- Qompass AI Diver Node.js DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------
local api = vim.api
local fn = vim.fn
local uv = vim.uv
local M = {}
local ADAPTER_NAME = 'pwa-node'
local CONFIGURED_FLAG = 'qompass_node_dap_configured'
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
	'*.mts',
	'*.cts',
}
local SOURCE_SUFFIXES = {
	['.js'] = true,
	['.jsx'] = true,
	['.mjs'] = true,
	['.cjs'] = true,
	['.ts'] = true,
	['.tsx'] = true,
	['.mts'] = true,
	['.cts'] = true,
}
local TYPESCRIPT_SUFFIXES = {
	['.ts'] = true,
	['.tsx'] = true,
	['.mts'] = true,
	['.cts'] = true,
}

local ROOT_MARKERS = {
	'package.json',
	'pnpm-lock.yaml',
	'yarn.lock',
	'package-lock.json',
	'npm-shrinkwrap.json',
	'tsconfig.json',
	'jsconfig.json',
	'.git',
}

M.adapters = {
	node = {
		name = ADAPTER_NAME,
		command = 'node',
	},
}
M.adapter = M.adapters.node
---@type string?
local cached_debug_server
---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.node',
	})
end
---@param command string
---@return boolean
local function executable(command)
	return fn.executable(command) == 1
end
---@param path string?
---@return boolean
local function file_exists(path)
	if type(path) ~= 'string' or path == '' then
		return false
	end
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == 'file'
end
---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end
---@param value string?
---@return string
local function trim(value)
	return type(value) == 'string' and vim.trim(value) or ''
end

---@param bufnr integer
---@return string
local function buffer_file(bufnr)
	return api.nvim_buf_get_name(bufnr)
end

---@param path string
---@return string
local function suffix(path)
	local lower = path:lower()

	for candidate in pairs(SOURCE_SUFFIXES) do
		if lower:sub(-#candidate) == candidate then
			return candidate
		end
	end

	return ''
end

---@param bufnr integer
---@return boolean
local function filename_matches(bufnr)
	return SOURCE_SUFFIXES[suffix(buffer_file(bufnr))] == true
end

---@param bufnr integer
---@return boolean
local function is_node_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
		return false
	end

	local name = buffer_file(bufnr)
	if name == '' or vim.bo[bufnr].buftype ~= '' then
		return false
	end

	return FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(bufnr)
end

---@param start string
---@return string
local function project_root(start)
	local root = vim.fs.root(start, ROOT_MARKERS)
	if root then
		return root
	end

	local directory = vim.fs.dirname(start)
	return directory or fn.getcwd()
end

---@param bufnr integer
---@return integer?, string?, string?
local function current_node_context(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	if not is_node_buffer(bufnr) then
		notify('Node DAP is available only in JavaScript/TypeScript source buffers', vim.log.levels.ERROR)
		return nil, nil, nil
	end
	local file = buffer_file(bufnr)
	local root = project_root(file)
	return bufnr, root, file
end
---@param path string
---@return table?
local function read_json(path)
	if not file_exists(path) then
		return nil
	end

	local ok, lines = pcall(fn.readfile, path)
	if not ok or type(lines) ~= 'table' or #lines == 0 then
		return nil
	end

	local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, '\n'))
	if not decoded_ok or type(decoded) ~= 'table' then
		return nil
	end

	return decoded
end

---@param root string
---@return table?
local function package_json(root)
	return read_json(vim.fs.joinpath(root, 'package.json'))
end

---@param items string[]
---@param prompt string
---@return string?
local function pick(items, prompt)
	if #items == 0 then
		return nil
	end

	if #items == 1 then
		return items[1]
	end

	local choices = { prompt }
	for index, item in ipairs(items) do
		choices[#choices + 1] = string.format('%d. %s', index, item)
	end

	local choice = fn.inputlist(choices)
	if choice < 1 or choice > #items then
		return nil
	end

	return items[choice]
end

---@param raw string
---@return string[]?, string?
local function parse_arguments(raw)
	local arguments = {}
	local current = {}
	local quote
	local escaped = false
	local token_started = false

	local function finish()
		if token_started then
			arguments[#arguments + 1] = table.concat(current)
			current = {}
			token_started = false
		end
	end

	for index = 1, #raw do
		local character = raw:sub(index, index)

		if escaped then
			current[#current + 1] = character
			escaped = false
			token_started = true
		elseif character == '\\' and quote ~= "'" then
			escaped = true
			token_started = true
		elseif quote then
			if character == quote then
				quote = nil
			else
				current[#current + 1] = character
			end
			token_started = true
		elseif character == '"' or character == "'" then
			quote = character
			token_started = true
		elseif character:match('%s') then
			finish()
		else
			current[#current + 1] = character
			token_started = true
		end
	end

	if escaped then
		return nil, 'Arguments end with an incomplete escape'
	end

	if quote then
		return nil, 'Arguments contain an unterminated quote'
	end

	finish()
	return arguments, nil
end

---@param prompt? string
---@return string[]?
local function prompt_arguments(prompt)
	local raw = input(prompt or 'Program arguments: ')
	local arguments, err = parse_arguments(raw)

	if not arguments then
		notify(err or 'Unable to parse arguments', vim.log.levels.ERROR)
		return nil
	end

	return arguments
end

---@return table<string, string>?
local function prompt_environment()
	local environment = {}

	while true do
		local name = trim(input('Environment variable (blank to finish): '))
		if name == '' then
			break
		end

		if not name:match('^[%a_][%w_]*$') then
			notify('Invalid environment-variable name: ' .. name, vim.log.levels.ERROR)
			return nil
		end

		environment[name] = input(('Value for %s: '):format(name))
	end

	return environment
end

---@param default integer
---@param prompt? string
---@return integer?
local function resolve_port(default, prompt)
	local value = tonumber(input(prompt or 'Inspector port: ', tostring(default)))

	if not value or value < 1 or value > 65535 or value % 1 ~= 0 then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return nil
	end

	return math.floor(value)
end

---@param root string
---@param name string
---@return string?
local function local_executable(root, name)
	local path = vim.fs.joinpath(root, 'node_modules', '.bin', name)
	return file_exists(path) and path or nil
end

---@param command string
---@return string?
local function executable_path(command)
	local path = fn.exepath(command)
	return path ~= '' and path or nil
end

---@param root string
---@param program string
---@return string?
local function resolve_runtime(root, program)
	if not TYPESCRIPT_SUFFIXES[suffix(program)] then
		return executable_path('node')
	end

	local tsx = local_executable(root, 'tsx') or executable_path('tsx')
	if tsx then
		return tsx
	end

	local ts_node = local_executable(root, 'ts-node') or executable_path('ts-node')
	if ts_node then
		return ts_node
	end

	local selected = input('TypeScript runtime (tsx or ts-node): ', '', 'shellcmd')
	if selected ~= '' and executable(selected) then
		return executable_path(selected) or selected
	end

	notify(
		'TypeScript requires an executable runtime such as tsx or ts-node; refusing an invalid launch',
		vim.log.levels.ERROR
	)
	return nil
end
---@param root string
---@return string[]
local function package_scripts(root)
	local package = package_json(root)
	if not package or type(package.scripts) ~= 'table' then
		return {}
	end

	local scripts = {}
	for name, command in pairs(package.scripts) do
		if type(name) == 'string' and type(command) == 'string' then
			scripts[#scripts + 1] = name
		end
	end

	table.sort(scripts)
	return scripts
end

---@param root string
---@return string?
local function package_manager(root)
	local package = package_json(root)
	local declared = package and type(package.packageManager) == 'string' and package.packageManager:match('^([^@]+)')

	local candidates = {}

	if declared then
		candidates[#candidates + 1] = declared
	end
	if file_exists(vim.fs.joinpath(root, 'pnpm-lock.yaml')) then
		candidates[#candidates + 1] = 'pnpm'
	end
	if file_exists(vim.fs.joinpath(root, 'yarn.lock')) then
		candidates[#candidates + 1] = 'yarn'
	end
	candidates[#candidates + 1] = 'npm'

	for _, candidate in ipairs(candidates) do
		if candidate and executable(candidate) then
			return executable_path(candidate) or candidate
		end
	end

	return nil
end

---@param root string
---@return string[]
local function skip_files(root)
	return {
		'<node_internals>/**',
		vim.fs.joinpath(root, 'node_modules', '**'),
	}
end

---@param root string
---@return string[]
local function out_files(root)
	return {
		vim.fs.joinpath(root, '**', '*.js'),
		vim.fs.joinpath(root, '**', '*.cjs'),
		vim.fs.joinpath(root, '**', '*.mjs'),
		'!' .. vim.fs.joinpath(root, 'node_modules', '**'),
	}
end

---@param root string
---@return string[]
local function source_map_locations(root)
	return {
		vim.fs.joinpath(root, '**'),
		'!' .. vim.fs.joinpath(root, 'node_modules', '**'),
	}
end

---@param root string
---@return table
local function common_configuration(root)
	return {
		type = ADAPTER_NAME,
		cwd = root,
		console = 'internalConsole',
		internalConsoleOptions = 'openOnSessionStart',
		outputCapture = 'std',
		skipFiles = skip_files(root),
		sourceMaps = true,
		smartStep = true,
		outFiles = out_files(root),
		resolveSourceMapLocations = source_map_locations(root),
	}
end

---@param destination table
---@param source table
---@return table
local function extend(destination, source)
	for key, value in pairs(source) do
		destination[key] = value
	end

	return destination
end

---@return string[]
local function debug_server_candidates()
	local data = fn.stdpath('data')
	local configured = vim.g.qompass_node_dap_server
	local environment = vim.env.NVIM_JS_DEBUG_SERVER

	return {
		type(configured) == 'string' and configured or '',
		type(environment) == 'string' and environment or '',
		vim.fs.joinpath(data, 'vscode-js-debug', 'js-debug', 'src', 'dapDebugServer.js'),
		vim.fs.joinpath(data, 'vscode-js-debug', 'src', 'dapDebugServer.js'),
		vim.fs.joinpath(data, 'vscode-js-debug', 'dapDebugServer.js'),
		'/usr/share/vscode-js-debug/dapDebugServer.js',
		'/usr/share/vscode-js-debug/src/dapDebugServer.js',
		'/usr/lib/vscode-js-debug/dapDebugServer.js',
		'/opt/vscode-js-debug/dapDebugServer.js',
	}
end

---@return string?
local function resolve_debug_server()
	if file_exists(cached_debug_server) then
		return cached_debug_server
	end

	for _, candidate in ipairs(debug_server_candidates()) do
		if file_exists(candidate) then
			cached_debug_server = candidate
			return candidate
		end
	end

	local selected = input(
		'Path to standalone vscode-js-debug dapDebugServer.js: ',
		vim.fs.joinpath(fn.stdpath('data'), 'vscode-js-debug') .. '/',
		'file'
	)

	if not file_exists(selected) then
		notify(
			'Standalone vscode-js-debug dapDebugServer.js was not found; set NVIM_JS_DEBUG_SERVER or vim.g.qompass_node_dap_server',
			vim.log.levels.ERROR
		)
		return nil
	end

	cached_debug_server = selected
	return selected
end

---@class NodeDapAdapter
---@field name string
---@field type string
---@field host string
---@field port string
---@field executable { command: string, args: string[] }

---@return NodeDapAdapter?
function M.resolve_adapter()
	local node = executable_path(M.adapters.node.command)
	if not node then
		notify('node not found in PATH', vim.log.levels.ERROR)
		return nil
	end

	local server = resolve_debug_server()
	if not server then
		return nil
	end

	local adapter = {
		name = ADAPTER_NAME,
		type = 'server',
		host = '127.0.0.1',
		port = '${port}',
		executable = {
			command = node,
			args = {
				server,
				'${port}',
				'127.0.0.1',
			},
		},
	}

	M.adapters.node.args = adapter.executable.args
	M.adapters.node.server = server

	return adapter
end

---@param silent? boolean
---@return table?
local function debug_client(silent)
	local client = rawget(vim, 'debug')

	if type(client) ~= 'table' or type(client.start) ~= 'function' then
		if not silent then
			notify(
				'vim.debug is unavailable. Neovim 0.13 does not include a native DAP client; load the same DAP core used by dap/android.lua',
				vim.log.levels.ERROR
			)
		end
		return nil
	end

	return client
end

---@param configuration table
local function start(configuration)
	local client = debug_client()
	if not client then
		return
	end

	local adapter = M.resolve_adapter()
	if not adapter then
		return
	end

	local ok, err = pcall(client.start, configuration, adapter)
	if not ok then
		notify('Unable to start Node DAP: ' .. tostring(err), vim.log.levels.ERROR)
	end
end

---@param file string
---@param root string
---@return string?
local function resolve_program(file, root)
	if file_exists(file) and SOURCE_SUFFIXES[suffix(file)] then
		return file
	end

	local selected = input('Node program: ', root .. '/', 'file')
	if not file_exists(selected) or not SOURCE_SUFFIXES[suffix(selected)] then
		notify('Select an existing JavaScript/TypeScript source file', vim.log.levels.ERROR)
		return nil
	end
	return selected
end
function M.run_file()
	local _, root, file = current_node_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	local program = resolve_program(file, root)
	if not program then
		return
	end

	local runtime = resolve_runtime(root, program)
	if not runtime then
		return
	end

	local arguments = prompt_arguments()
	if not arguments then
		return
	end

	local environment = prompt_environment()
	if not environment then
		return
	end

	start(extend(common_configuration(root), {
		request = 'launch',
		name = 'Node: launch current file',
		program = program,
		runtimeExecutable = runtime,
		args = arguments,
		env = environment,
	}))
end

function M.run_package_script()
	local _, root = current_node_context(api.nvim_get_current_buf())
	if not root then
		return
	end

	local script = pick(package_scripts(root), 'Package script:')
	if not script then
		notify('No package.json script selected', vim.log.levels.WARN)
		return
	end
	local manager = package_manager(root)
	if not manager then
		notify('No supported package manager found in PATH', vim.log.levels.ERROR)
		return
	end
	local arguments = prompt_arguments('Script arguments: ')
	if not arguments then
		return
	end
	local environment = prompt_environment()
	if not environment then
		return
	end
	local runtime_arguments = {
		'run',
		script,
	}
	if #arguments > 0 then
		runtime_arguments[#runtime_arguments + 1] = '--'
		vim.list_extend(runtime_arguments, arguments)
	end

	start(extend(common_configuration(root), {
		request = 'launch',
		name = ('Node: %s run %s'):format(fn.fnamemodify(manager, ':t'), script),
		runtimeExecutable = manager,
		runtimeArgs = runtime_arguments,
		env = environment,
	}))
end

function M.attach_port()
	local _, root = current_node_context(api.nvim_get_current_buf())
	if not root then
		return
	end

	local port = resolve_port(9229)
	if not port then
		return
	end

	start(extend(common_configuration(root), {
		request = 'attach',
		name = ('Node: attach 127.0.0.1:%d'):format(port),
		address = '127.0.0.1',
		port = port,
		continueOnAttach = true,
		restart = false,
	}))
end
function M.attach_pid()
	local _, root = current_node_context(api.nvim_get_current_buf())
	if not root then
		return
	end
	local value = trim(input('Node process ID: '))
	local pid = tonumber(value)
	if not pid or pid < 1 or pid % 1 ~= 0 then
		notify('Process ID must be a positive integer', vim.log.levels.ERROR)
		return
	end
	start(extend(common_configuration(root), {
		request = 'attach',
		name = ('Node: attach PID %d'):format(pid),
		processId = tostring(math.floor(pid)),
		continueOnAttach = true,
	}))
end
---@param root string
---@param candidates string[]
---@return string?
local function first_existing(root, candidates)
	for _, candidate in ipairs(candidates) do
		local path = vim.fs.joinpath(root, candidate)
		if file_exists(path) then
			return path
		end
	end
	return nil
end
---@param runner string
---@param candidates string[]
---@param default_arguments string[]
local function run_test_runner(runner, candidates, default_arguments)
	local _, root = current_node_context(api.nvim_get_current_buf())
	if not root then
		return
	end

	local program = first_existing(root, candidates)
	if not program then
		notify(('%s was not found in this workspace'):format(runner), vim.log.levels.ERROR)
		return
	end

	local extra_arguments = prompt_arguments(('%s arguments: '):format(runner))
	if not extra_arguments then
		return
	end

	local environment = prompt_environment()
	if not environment then
		return
	end

	local arguments = vim.deepcopy(default_arguments)
	vim.list_extend(arguments, extra_arguments)

	start(extend(common_configuration(root), {
		request = 'launch',
		name = ('Node: debug %s'):format(runner),
		program = program,
		runtimeExecutable = executable_path('node'),
		args = arguments,
		env = environment,
	}))
end

function M.run_jest()
	run_test_runner('Jest', {
		'node_modules/jest/bin/jest.js',
		'node_modules/jest-cli/bin/jest.js',
	}, {
		'--runInBand',
	})
end

function M.run_vitest()
	run_test_runner('Vitest', {
		'node_modules/vitest/vitest.mjs',
	}, {
		'--no-file-parallelism',
	})
end

function M.run_mocha()
	run_test_runner('Mocha', {
		'node_modules/mocha/bin/mocha.js',
		'node_modules/mocha/bin/_mocha',
	}, {})
end
M.run_npm_script = M.run_package_script
M.attach_next_dev = M.attach_port
---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_node_buffer(bufnr) or vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end

	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, 'NodeDapRun', M.run_file, {
		desc = 'Debug the current JavaScript/TypeScript file with Node',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapScript', M.run_package_script, {
		desc = 'Debug a package.json script',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapAttach', M.attach_port, {
		desc = 'Attach to a Node inspector on 127.0.0.1',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapAttachPid', M.attach_pid, {
		desc = 'Attach to a Node process ID',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapNext', M.attach_next_dev, {
		desc = 'Attach to a Next.js Node inspector on 127.0.0.1',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapJest', M.run_jest, {
		desc = 'Debug Jest',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapVitest', M.run_vitest, {
		desc = 'Debug Vitest',
	})
	api.nvim_buf_create_user_command(bufnr, 'NodeDapMocha', M.run_mocha, {
		desc = 'Debug Mocha',
	})

	local function map(lhs, rhs, description)
		vim.keymap.set('n', lhs, rhs, {
			buffer = bufnr,
			desc = description,
			silent = true,
		})
	end

	map('<leader>dnl', M.run_file, 'Node launch file')
	map('<leader>dns', M.run_package_script, 'Node package script')
	map('<leader>dna', M.attach_port, 'Node attach port')
	map('<leader>dnp', M.attach_pid, 'Node attach PID')
	map('<leader>dnn', M.attach_next_dev, 'Node attach Next.js')
	map('<leader>dnj', M.run_jest, 'Node debug Jest')
	map('<leader>dnv', M.run_vitest, 'Node debug Vitest')
	map('<leader>dnm', M.run_mocha, 'Node debug Mocha')
end

function M.setup()
	local group = api.nvim_create_augroup('qompass.dap.node', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Node DAP for JavaScript/TypeScript buffers',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = 'Enable Node DAP for JavaScript/TypeScript source files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
