-- ~/.config/nvim/lua/dap/lua.lua
--
-- actboy168/lua-debug.

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug

local M = {}

M.adapter = {
	name = 'lua',
	command = 'lua-debug',
}

M.configurations = {
	lua = {},
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.lua' })
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

local function current_dir()
	local file = current_file()
	if file == '' then
		return cwd()
	end
	return fn.fnamemodify(file, ':p:h')
end

local function workspace_root()
	local file = current_file()
	if file == '' then
		return cwd()
	end

	local root_markers = {
		'.git',
		'.luarc.json',
		'.luarc.jsonc',
		'selene.toml',
		'stylua.toml',
		'.stylua.toml',
		'init.lua',
	}

	local root = vim.fs.root(file, root_markers)
	return root or cwd()
end

local function file_exists(path)
	return type(path) == 'string' and path ~= '' and uv.fs_stat(path) ~= nil
end

local function lua_bin()
	if executable('luajit') then
		return 'luajit'
	end
	if executable('lua') then
		return 'lua'
	end
	return nil
end

local function resolve_program()
	local file = current_file()
	if file ~= '' then
		return file
	end

	local program = input('Lua program: ', cwd() .. '/', 'file')
	if program == '' then
		return nil
	end
	return program
end

local function resolve_args()
	local raw = input('Args: ', '')
	if raw == '' then
		return {}
	end
	return vim.split(raw, '%s+', { trimempty = true })
end

local function resolve_host()
	local host = input('Host: ', '127.0.0.1')
	if host == '' then
		return '127.0.0.1'
	end
	return host
end

local function resolve_port(default)
	local port = tonumber(input('Port: ', tostring(default or 8818)))
	if not port then
		return nil
	end
	return port
end

local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end

	notify(
		('Lua DAP adapter not found: %s Install/build a standalone adapter such as actboy168/lua-debug and make it available in PATH.'):format(
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

function M.launch_file()
	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Lua program not found', vim.log.levels.ERROR)
		return
	end

	local lua = lua_bin()
	if not lua then
		notify('Neither lua nor luajit was found in PATH', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Launch current Lua file',
		cwd = workspace_root(),
		program = program,
		runtimeExecutable = lua,
		args = resolve_args(),
		stopOnEntry = false,
	})
end

function M.launch_project_main()
	local root = workspace_root()
	local candidates = {
		root .. '/main.lua',
		root .. '/init.lua',
		root .. '/lua/main.lua',
	}

	local program
	for _, candidate in ipairs(candidates) do
		if file_exists(candidate) then
			program = candidate
			break
		end
	end

	if not program then
		program = input('Project entry Lua file: ', root .. '/', 'file')
	end

	if not program or program == '' or not file_exists(program) then
		notify('Project entry Lua file not found', vim.log.levels.ERROR)
		return
	end

	local lua = lua_bin()
	if not lua then
		notify('Neither lua nor luajit was found in PATH', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Launch Lua project',
		cwd = root,
		program = program,
		runtimeExecutable = lua,
		args = resolve_args(),
		stopOnEntry = false,
	})
end

function M.launch_with_luajit()
	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Lua program not found', vim.log.levels.ERROR)
		return
	end

	if not executable('luajit') then
		notify('luajit not found in PATH', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Launch with LuaJIT',
		cwd = workspace_root(),
		program = program,
		runtimeExecutable = 'luajit',
		args = resolve_args(),
		stopOnEntry = false,
	})
end
function M.attach_remote()
	local host = resolve_host()
	local port = resolve_port(8818)
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end
	start({
		request = 'attach',
		name = 'Attach to remote Lua',
		host = host,
		port = port,
		cwd = workspace_root(),
	})
end
function M.attach_local_socket()
	local port = resolve_port(8818)
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end
	start({
		request = 'attach',
		name = 'Attach to local Lua debug server',
		host = '127.0.0.1',
		port = port,
		cwd = workspace_root(),
	})
end

function M.debug_neovim_lua()
	local init = fn.stdpath('config') .. '/init.lua'
	local target = current_file()
	if target == '' then
		target = init
	end
	if not file_exists(target) then
		notify('Target file not found', vim.log.levels.ERROR)
		return
	end
	local nvim = fn.exepath('nvim')
	if nvim == '' then
		notify('nvim executable not found', vim.log.levels.ERROR)
		return
	end
	start({
		request = 'launch',
		name = 'Debug Neovim Lua file',
		cwd = workspace_root(),
		program = target,
		runtimeExecutable = nvim,
		args = {
			'--clean',
			'-l',
			target,
		},
		stopOnEntry = false,
	})
end

function M.debug_busted()
	local root = workspace_root()
	if not executable('busted') then
		notify('busted not found in PATH', vim.log.levels.ERROR)
		return
	end
	local file = current_file()
	if file == '' then
		file = input('Busted test file: ', root .. '/tests/', 'file')
	end
	if file == '' or not file_exists(file) then
		notify('Busted test file not found', vim.log.levels.ERROR)
		return
	end
	start({
		request = 'launch',
		name = 'Debug busted test',
		cwd = root,
		program = file,
		runtimeExecutable = 'busted',
		args = { file },
		stopOnEntry = false,
	})
end
function M.debug_one_shot()
	local expr = input('Lua expression: ', 'print(vim.inspect(vim.version()))')
	if expr == '' then
		return
	end

	local temp = fn.tempname() .. '.lua'
	fn.writefile({ expr }, temp)

	local lua = lua_bin()
	if not lua then
		notify('Neither lua nor luajit was found in PATH', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Debug Lua expression',
		cwd = current_dir(),
		program = temp,
		runtimeExecutable = lua,
		args = {},
		stopOnEntry = true,
	})
end

function M.setup()
	api.nvim_create_user_command('LuaDapLaunchFile', M.launch_file, {
		desc = 'Debug current Lua file',
	})

	api.nvim_create_user_command('LuaDapLaunchProject', M.launch_project_main, {
		desc = 'Debug Lua project entry file',
	})

	api.nvim_create_user_command('LuaDapLaunchJit', M.launch_with_luajit, {
		desc = 'Debug Lua file with LuaJIT',
	})

	api.nvim_create_user_command('LuaDapAttach', M.attach_local_socket, {
		desc = 'Attach to local Lua debug server',
	})

	api.nvim_create_user_command('LuaDapAttachRemote', M.attach_remote, {
		desc = 'Attach to remote Lua debug server',
	})

	api.nvim_create_user_command('LuaDapNeovim', M.debug_neovim_lua, {
		desc = 'Debug Lua using Neovim as the runtime',
	})
	api.nvim_create_user_command('LuaDapBusted', M.debug_busted, {
		desc = 'Debug current busted test file',
	})
	api.nvim_create_user_command('LuaDapExpr', M.debug_one_shot, {
		desc = 'Debug a one-shot Lua expression',
	})

	vim.keymap.set('n', '<leader>ul', M.launch_file, { desc = 'Lua DAP launch file' })
	vim.keymap.set('n', '<leader>up', M.launch_project_main, { desc = 'Lua DAP launch project' })
	vim.keymap.set('n', '<leader>uj', M.launch_with_luajit, { desc = 'Lua DAP launch LuaJIT' })
	vim.keymap.set('n', '<leader>ua', M.attach_local_socket, { desc = 'Lua DAP attach' })
	vim.keymap.set('n', '<leader>uA', M.attach_remote, { desc = 'Lua DAP attach remote' })
	vim.keymap.set('n', '<leader>un', M.debug_neovim_lua, { desc = 'Lua DAP Neovim runtime' })
	vim.keymap.set('n', '<leader>ut', M.debug_busted, { desc = 'Lua DAP busted' })
	vim.keymap.set('n', '<leader>ux', M.debug_one_shot, { desc = 'Lua DAP expression' })
end

return M
