-- ~/.config/nvim/lua/dap/lua.lua
-- Qompass AI Diver Lua DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv
local M = {}
local FILETYPES = {
	lua = true,
}
local FILETYPE_PATTERNS = {
	'lua',
}
local FILE_PATTERNS = {
	'*.lua',
}
local ROOT_MARKERS = {
	'.git',
	'.luarc.json',
	'.luarc.jsonc',
	'.busted',
	'rocks.toml',
	'selene.toml',
	'stylua.toml',
	'.stylua.toml',
	'init.lua',
}
local CONFIGURED_FLAG = 'qompass_lua_dap_configured'
local setup_done = false

M.adapter = {
	name = 'lua',
	command = 'lua-debug',
}

M.configurations = {
	lua = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.lua',
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
local function is_lua_buffer(bufnr)
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
local function current_lua_context()
	local bufnr = api.nvim_get_current_buf()

	if not is_lua_buffer(bufnr) then
		notify('Lua DAP is available only in saved Lua buffers', vim.log.levels.ERROR)
		return nil, nil
	end

	return bufnr, project_root(bufnr)
end

---@param bufnr integer
---@return boolean
local function update_buffer(bufnr)
	local filename = buffer_file(bufnr)
	if filename == '' then
		notify('Save the Lua buffer before debugging', vim.log.levels.ERROR)
		return false
	end

	if not vim.bo[bufnr].modified then
		return true
	end

	local ok, err = pcall(api.nvim_buf_call, bufnr, function()
		vim.cmd('silent update')
	end)

	if not ok then
		notify('Unable to save the Lua buffer: ' .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@return boolean
local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end

	notify(
		(
			'Lua DAP adapter not found: %s. '
			.. 'Install or build actboy168/lua-debug and '
			.. 'make the adapter available in PATH.'
		):format(M.adapter.command),
		vim.log.levels.ERROR
	)
	return false
end

---@param require_luajit? boolean
---@return string?
local function lua_runtime(require_luajit)
	if require_luajit then
		return executable('luajit') and 'luajit' or nil
	end

	if executable('luajit') then
		return 'luajit'
	end

	if executable('lua') then
		return 'lua'
	end

	return nil
end

---@param label? string
---@return string[]?
local function prompt_args(label)
	local raw = input(label or 'Arguments: ', '')
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

---@param default? string
---@return string?
local function prompt_host(default)
	local host = input('Host: ', default or '127.0.0.1')
	if host == '' then
		host = default or '127.0.0.1'
	end

	if not safe_single_line(host) then
		notify('Invalid host', vim.log.levels.ERROR)
		return nil
	end

	return host
end

---@param default? integer
---@return integer?
local function prompt_port(default)
	local raw = input('Port: ', tostring(default or 8818))
	local value = tonumber(raw)

	if value == nil or value % 1 ~= 0 or value < 1 or value > 65535 then
		notify('Port must be an integer from 1 to 65535', vim.log.levels.ERROR)
		return nil
	end

	return math.floor(value)
end

---@param bufnr integer
---@param root string
---@param config table<string, any>
local function start(bufnr, root, config)
	if not is_lua_buffer(bufnr) then
		notify('Lua DAP can be started only from a Lua buffer', vim.log.levels.ERROR)
		return
	end

	if not update_buffer(bufnr) or not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
	config.cwd = config.cwd or root
	debug.start(config)
end

function M.launch_file()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local filename = buffer_file(bufnr)
	if not file_exists(filename) then
		notify('Current Lua file does not exist on disk', vim.log.levels.ERROR)
		return
	end

	local runtime = lua_runtime()
	if runtime == nil then
		notify('Neither lua nor luajit was found in PATH', vim.log.levels.ERROR)
		return
	end

	local args = prompt_args()
	if args == nil then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Launch current Lua file',
		program = filename,
		runtimeExecutable = runtime,
		args = args,
		stopOnEntry = false,
	})
end

---@param root string
---@return string?
local function project_entry(root)
	local candidates = {
		vim.fs.joinpath(root, 'main.lua'),
		vim.fs.joinpath(root, 'init.lua'),
		vim.fs.joinpath(root, 'lua', 'main.lua'),
	}

	for _, candidate in ipairs(candidates) do
		if file_exists(candidate) then
			return candidate
		end
	end

	local selected = input('Project entry Lua file: ', root .. '/', 'file')
	if selected == '' then
		return nil
	end

	return fn.fnamemodify(selected, ':p')
end

function M.launch_project_main()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local program = project_entry(root)
	if program == nil or not file_exists(program) then
		notify('Project entry Lua file not found', vim.log.levels.ERROR)
		return
	end

	local runtime = lua_runtime()
	if runtime == nil then
		notify('Neither lua nor luajit was found in PATH', vim.log.levels.ERROR)
		return
	end

	local args = prompt_args()
	if args == nil then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Launch Lua project',
		program = program,
		runtimeExecutable = runtime,
		args = args,
		stopOnEntry = false,
	})
end

function M.launch_with_luajit()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local filename = buffer_file(bufnr)
	if not file_exists(filename) then
		notify('Current Lua file does not exist on disk', vim.log.levels.ERROR)
		return
	end

	local runtime = lua_runtime(true)
	if runtime == nil then
		notify('luajit was not found in PATH', vim.log.levels.ERROR)
		return
	end

	local args = prompt_args()
	if args == nil then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Launch current Lua file with LuaJIT',
		program = filename,
		runtimeExecutable = runtime,
		args = args,
		stopOnEntry = false,
	})
end

function M.attach_local_socket()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local port = prompt_port(8818)
	if port == nil then
		return
	end

	start(bufnr, root, {
		request = 'attach',
		name = 'Attach to local Lua debug server',
		host = '127.0.0.1',
		port = port,
	})
end

function M.attach_remote()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local host = prompt_host()
	if host == nil then
		return
	end

	local port = prompt_port(8818)
	if port == nil then
		return
	end

	start(bufnr, root, {
		request = 'attach',
		name = 'Attach to remote Lua debug server',
		host = host,
		port = port,
	})
end

function M.debug_neovim_lua()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local target = buffer_file(bufnr)
	if not file_exists(target) then
		notify('Current Lua file does not exist on disk', vim.log.levels.ERROR)
		return
	end

	local nvim = fn.exepath('nvim')
	if nvim == '' then
		notify('nvim executable was not found', vim.log.levels.ERROR)
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Debug current Lua file with Neovim',
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
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	if not executable('busted') then
		notify('busted was not found in PATH', vim.log.levels.ERROR)
		return
	end

	local test_file = buffer_file(bufnr)
	if not file_exists(test_file) then
		notify('Current busted test file does not exist on disk', vim.log.levels.ERROR)
		return
	end

	local args = prompt_args('Busted arguments: ')
	if args == nil then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Debug current busted test',
		program = test_file,
		runtimeExecutable = 'busted',
		args = args,
		stopOnEntry = false,
	})
end

function M.debug_one_shot()
	local bufnr, root = current_lua_context()
	if bufnr == nil or root == nil then
		return
	end

	local runtime = lua_runtime()
	if runtime == nil then
		notify('Neither lua nor luajit was found in PATH', vim.log.levels.ERROR)
		return
	end

	local expression = input('Lua expression: ', 'print(vim.inspect(vim.version()))')
	if expression == '' then
		return
	end

	if not safe_single_line(expression) then
		notify('The Lua expression must be entered on one line', vim.log.levels.ERROR)
		return
	end

	local temporary = fn.tempname() .. '.lua'
	local ok, result = pcall(fn.writefile, {
		expression,
	}, temporary)
	if not ok or result ~= 0 then
		notify('Unable to create the temporary Lua file', vim.log.levels.ERROR)
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Debug one-shot Lua expression',
		program = temporary,
		runtimeExecutable = runtime,
		args = {},
		stopOnEntry = true,
	})
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_lua_buffer(bufnr) then
		return
	end

	if vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end
	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, 'LuaDapLaunchFile', M.launch_file, {
		desc = 'Debug the current Lua file',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapLaunchProject', M.launch_project_main, {
		desc = 'Debug the Lua project entry file',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapLaunchJit', M.launch_with_luajit, {
		desc = 'Debug the current Lua file with LuaJIT',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapAttach', M.attach_local_socket, {
		desc = 'Attach to a local Lua debug server',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapAttachRemote', M.attach_remote, {
		desc = 'Attach to a remote Lua debug server',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapNeovim', M.debug_neovim_lua, {
		desc = 'Debug the current Lua file with Neovim',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapBusted', M.debug_busted, {
		desc = 'Debug the current busted test file',
	})
	api.nvim_buf_create_user_command(bufnr, 'LuaDapExpr', M.debug_one_shot, {
		desc = 'Debug a one-shot Lua expression',
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

	map('<leader>dlf', M.launch_file, 'Lua DAP current file')
	map('<leader>dlp', M.launch_project_main, 'Lua DAP project')
	map('<leader>dlj', M.launch_with_luajit, 'Lua DAP LuaJIT')
	map('<leader>dla', M.attach_local_socket, 'Lua DAP attach')
	map('<leader>dlA', M.attach_remote, 'Lua DAP attach remote')
	map('<leader>dln', M.debug_neovim_lua, 'Lua DAP Neovim runtime')
	map('<leader>dlt', M.debug_busted, 'Lua DAP busted')
	map('<leader>dlx', M.debug_one_shot, 'Lua DAP expression')
end

function M.setup()
	if setup_done then
		configure_buffer(api.nvim_get_current_buf())
		return
	end
	setup_done = true

	local group = api.nvim_create_augroup('qompass.dap.lua', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Lua DAP for Lua filetypes',
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
		desc = 'Enable Lua DAP for Lua files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
