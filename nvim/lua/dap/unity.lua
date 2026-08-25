-- ~/.config/nvim/lua/dap/unity.lua
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local FILETYPES = { cs = true }
local FILETYPE_PATTERNS = { 'cs' }
local FILE_PATTERNS = { '*.cs' }
local M = {}

M.adapter = {
	name = 'coreclr',
	command = 'netcoredbg',
	args = { '--interpreter=vscode' },
}
local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.unity' })
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
		'Assets',
		'Packages',
		'ProjectSettings',
		'*.sln',
		'.git',
	})

	return root or cwd()
end

local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end

	notify(
		('Unity debugger not found: %sInstall Samsung/netcoredbg and put it in PATH.'):format(M.adapter.command),
		vim.log.levels.ERROR
	)
	return false
end

local function start(config)
	if not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
	config.adapter = {
		type = 'executable',
		command = M.adapter.command,
		args = M.adapter.args,
	}
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

local function unity_root()
	local root = workspace_root()
	if is_dir(path_join(root, 'Assets')) and is_dir(path_join(root, 'ProjectSettings')) then
		return root
	end
	return root
end

local function dll_candidates(root)
	local product = fn.fnamemodify(root, ':t')
	return {
		path_join(root, 'Library', 'ScriptAssemblies', 'Assembly-CSharp.dll'),
		path_join(root, 'Library', 'ScriptAssemblies', 'Assembly-CSharp-Editor.dll'),
		path_join(root, 'Build', product .. '.dll'),
		path_join(root, product .. '.dll'),
	}
end

local function guess_unity_dll()
	local root = unity_root()
	for _, dll in ipairs(dll_candidates(root)) do
		if file_exists(dll) then
			return dll
		end
	end
	return path_join(root, 'Library', 'ScriptAssemblies', 'Assembly-CSharp.dll')
end

local function prompt_program()
	local dll = input('Path to Unity managed DLL: ', guess_unity_dll(), 'file')
	if dll == '' then
		return nil
	end
	return dll
end

local function pick_pid_from_ps()
	local cmd = [[ps -eo pid=,comm= | grep -Ei 'Unity|UnityHub|mono|dotnet' | head -n 50]]
	local result = vim.system({ 'sh', '-c', cmd }, { text = true }):wait()

	if result.code ~= 0 or not result.stdout or result.stdout == '' then
		return nil
	end

	local lines = vim.split(vim.trim(result.stdout), '', { trimempty = true })
	if #lines == 0 then
		return nil
	end

	local choices = { 'Select Unity/.NET process:' }
	for i, line in ipairs(lines) do
		choices[#choices + 1] = string.format('%d. %s', i, vim.trim(line))
	end

	local idx = fn.inputlist(choices)
	if idx < 1 or idx > #lines then
		return nil
	end

	local pid = tonumber(vim.trim(lines[idx]):match('^(%d+)'))
	return pid
end

function M.launch_dll()
	local program = prompt_program()
	if not program or program == '' then
		notify('Managed DLL path is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Unity launch managed DLL',
		program = program,
		cwd = unity_root(),
		args = prompt_args(),
		env = prompt_env(),
		stopAtEntry = false,
		console = 'internalConsole',
	})
end

function M.attach_pid()
	local pid = pick_pid_from_ps()
	if not pid then
		pid = tonumber(input('PID: ', ''))
	end

	if not pid then
		notify('Invalid PID', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'attach',
		name = 'Unity attach PID',
		processId = pid,
		cwd = unity_root(),
	})
end

function M.attach_server()
	local port = tonumber(input('Port: ', '4711'))
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	debug.start({
		type = 'unity-server',
		request = 'attach',
		name = 'Unity attach server',
		host = input('Host: ', '127.0.0.1'),
		port = port,
	})
end

function M.open_script_assemblies()
	local root = unity_root()
	local dir = path_join(root, 'Library', 'ScriptAssemblies')

	if not is_dir(dir) then
		notify('Library/ScriptAssemblies not found', vim.log.levels.WARN)
		return
	end

	vim.cmd('edit ' .. fn.fnameescape(dir))
end

function M.unity_info()
	local root = unity_root()
	local lines = {
		'Unity DAP notes',
		'',
		'Project root: ' .. root,
		'Managed assembly guess: ' .. guess_unity_dll(),
		'',
		'Recommended workflow:',
		'- Use your C# LSP for code intelligence.',
		'- Let Unity generate .sln/.csproj files.',
		'- Use :UnityDapAttach for a running Unity-related process.',
		'- Use :UnityDapLaunch if you specifically want to launch a managed DLL.',
		'',
		'Adapter:',
		'- netcoredbg --interpreter=vscode',
	}

	vim.cmd('new')
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = 'wipe'
	vim.bo[buf].filetype = 'markdown'
end

function M.setup()
	api.nvim_create_user_command('UnityDapLaunch', M.launch_dll, {
		desc = 'Launch Unity managed DLL with netcoredbg',
	})

	api.nvim_create_user_command('UnityDapAttach', M.attach_pid, {
		desc = 'Attach to running Unity/.NET process',
	})

	api.nvim_create_user_command('UnityDapServer', M.attach_server, {
		desc = 'Attach to Unity debug server/port',
	})

	api.nvim_create_user_command('UnityScriptAssemblies', M.open_script_assemblies, {
		desc = 'Open Unity Library/ScriptAssemblies directory',
	})

	api.nvim_create_user_command('UnityDapInfo', M.unity_info, {
		desc = 'Show Unity DAP info',
	})

	vim.keymap.set('n', '<leader>ul', M.launch_dll, { desc = 'Unity DAP launch' })
	vim.keymap.set('n', '<leader>ua', M.attach_pid, { desc = 'Unity DAP attach' })
	vim.keymap.set('n', '<leader>us', M.attach_server, { desc = 'Unity DAP server' })
	vim.keymap.set('n', '<leader>ui', M.unity_info, { desc = 'Unity DAP info' })
end

return M
