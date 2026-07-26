-- ~/.config/nvim/lua/dap/zig.lua
-- Zig DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local FILETYPES = { zig = true }
local FILETYPE_PATTERNS = { 'zig' }
local FILE_PATTERNS = { '*.zig' }
local M = {}

M.adapters = {
	primary = {
		name = 'lldb-dap',
		command = 'lldb-dap',
	},
	fallback = {
		name = 'codelldb',
		command = 'codelldb',
	},
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.zig' })
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
		'build.zig',
		'build.zig.zon',
		'.git',
	})

	return root or cwd()
end

local function project_name()
	return fn.fnamemodify(workspace_root(), ':t')
end

local function zig_out_bin()
	return path_join(workspace_root(), 'zig-out', 'bin')
end

local function zig_cache_bin()
	return path_join(workspace_root(), 'zig-cache', 'bin')
end

local function resolve_adapter()
	if executable(M.adapters.primary.command) then
		return M.adapters.primary
	end
	if executable(M.adapters.fallback.command) then
		return M.adapters.fallback
	end

	notify(
		('No Zig-capable LLDB DAP adapter found. Install %s or %s.'):format(
			M.adapters.primary.command,
			M.adapters.fallback.command
		),
		vim.log.levels.ERROR
	)
	return nil
end

local function start(config)
	local adapter = resolve_adapter()
	if not adapter then
		return
	end

	config.type = adapter.name
	debug.start(config)
end

local function system(cmd, opts)
	return vim.system(
		cmd,
		vim.tbl_extend('force', {
			text = true,
			cwd = workspace_root(),
		}, opts or {})
	):wait()
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

local function scan_dir_for_bins(dir)
	local out = {}
	if not is_dir(dir) then
		return out
	end

	local scan = uv.fs_scandir(dir)
	if not scan then
		return out
	end

	while true do
		local name, typ = uv.fs_scandir_next(scan)
		if not name then
			break
		end

		local path = path_join(dir, name)
		if typ == 'file' and fn.executable(path) == 1 then
			out[#out + 1] = path
		end
	end

	table.sort(out)
	return out
end

local function choose(items, prompt, formatter)
	if #items == 0 then
		return nil
	end

	local choices = { prompt or 'Select:' }
	for i, item in ipairs(items) do
		local label = formatter and formatter(item) or tostring(item)
		choices[#choices + 1] = string.format('%d. %s', i, label)
	end

	local idx = fn.inputlist(choices)
	if idx < 1 or idx > #items then
		return nil
	end

	return items[idx]
end

local function candidate_programs()
	local items = {}

	local explicit = path_join(zig_out_bin(), project_name())
	if file_exists(explicit) then
		items[#items + 1] = explicit
	end

	for _, path in ipairs(scan_dir_for_bins(zig_out_bin())) do
		if not vim.tbl_contains(items, path) then
			items[#items + 1] = path
		end
	end

	for _, path in ipairs(scan_dir_for_bins(zig_cache_bin())) do
		if not vim.tbl_contains(items, path) then
			items[#items + 1] = path
		end
	end

	return items
end

local function resolve_program()
	local candidates = candidate_programs()

	if #candidates == 1 then
		return candidates[1]
	end

	if #candidates > 1 then
		local picked = choose(candidates, 'Zig executable:', function(item)
			return item:gsub('^' .. vim.pesc(workspace_root() .. '/'), '')
		end)
		if picked then
			return picked
		end
	end

	local program = input('Path to Zig executable: ', zig_out_bin() .. '/', 'file')
	if program == '' then
		return nil
	end
	return program
end

function M.build()
	local result = system({ 'zig', 'build' })
	if result.code ~= 0 then
		notify(result.stderr ~= '' and result.stderr or 'zig build failed', vim.log.levels.ERROR)
		return
	end
	notify('zig build complete')
end

function M.build_release()
	local result = system({ 'zig', 'build', '-Doptimize=ReleaseSafe' })
	if result.code ~= 0 then
		notify(result.stderr ~= '' and result.stderr or 'zig build release failed', vim.log.levels.ERROR)
		return
	end
	notify('zig build -Doptimize=ReleaseSafe complete')
end

function M.launch()
	local result = system({ 'zig', 'build' })
	if result.code ~= 0 then
		notify(result.stderr ~= '' and result.stderr or 'zig build failed', vim.log.levels.ERROR)
		return
	end

	local program = resolve_program()
	if not program or not file_exists(program) then
		notify('Zig executable not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Zig launch',
		program = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'zig' },
	})
end

function M.launch_current_binary()
	local default = path_join(zig_out_bin(), project_name())
	local program = input('Path to Zig executable: ', default, 'file')

	if program == '' or not file_exists(program) then
		notify('Zig executable not found', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Zig launch executable',
		program = program,
		cwd = workspace_root(),
		args = prompt_args(),
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'zig' },
	})
end

function M.test_current_file()
	local file = current_file()
	if file == '' or not file_exists(file) then
		notify('Current Zig file not found', vim.log.levels.ERROR)
		return
	end

	if not executable('zig') then
		notify('zig not found in PATH', vim.log.levels.ERROR)
		return
	end

	local out_name = fn.fnamemodify(file, ':t:r') .. '-test'
	local out_bin = path_join(zig_out_bin(), out_name)

	fn.mkdir(zig_out_bin(), 'p')

	local result = system({
		'zig',
		'test',
		'-femit-bin=' .. out_bin,
		'--test-no-exec',
		file,
	})

	if result.code ~= 0 then
		notify(result.stderr ~= '' and result.stderr or 'zig test build failed', vim.log.levels.ERROR)
		return
	end

	if not file_exists(out_bin) then
		notify('Compiled Zig test binary not found', vim.log.levels.ERROR)
		return
	end

	local zig_bin = fn.exepath('zig')
	local args = {}

	if zig_bin ~= '' then
		args[#args + 1] = zig_bin
	end

	vim.list_extend(args, prompt_args())

	start({
		request = 'launch',
		name = 'Zig test current file',
		program = out_bin,
		cwd = workspace_root(),
		args = args,
		env = prompt_env(),
		stopOnEntry = false,
		sourceLanguages = { 'zig' },
	})
end

function M.attach_pid()
	local pid = tonumber(input('PID: ', ''))
	if not pid then
		notify('Invalid PID', vim.log.levels.ERROR)
		return
	end

	local program = input('Path to Zig executable (optional): ', zig_out_bin() .. '/', 'file')
	if program == '' then
		program = nil
	end

	start({
		request = 'attach',
		name = 'Zig attach PID',
		pid = pid,
		program = program,
		cwd = workspace_root(),
		sourceLanguages = { 'zig' },
	})
end

function M.setup()
	api.nvim_create_user_command('ZigDapBuild', M.build, {
		desc = 'zig build',
	})

	api.nvim_create_user_command('ZigDapBuildRelease', M.build_release, {
		desc = 'zig build -Doptimize=ReleaseSafe',
	})

	api.nvim_create_user_command('ZigDapLaunch', M.launch, {
		desc = 'Build and debug Zig executable',
	})

	api.nvim_create_user_command('ZigDapExec', M.launch_current_binary, {
		desc = 'Debug selected Zig executable',
	})

	api.nvim_create_user_command('ZigDapTest', M.test_current_file, {
		desc = 'Build and debug Zig test binary for current file',
	})

	api.nvim_create_user_command('ZigDapAttach', M.attach_pid, {
		desc = 'Attach debugger to Zig process',
	})

	vim.keymap.set('n', '<leader>zb', M.build, {
		desc = 'Zig DAP build',
	})
	vim.keymap.set('n', '<leader>zB', M.build_release, { desc = 'Zig DAP build release' })
	vim.keymap.set('n', '<leader>zd', M.launch, { desc = 'Zig DAP launch' })
	vim.keymap.set('n', '<leader>ze', M.launch_current_binary, { desc = 'Zig DAP executable' })
	vim.keymap.set('n', '<leader>zt', M.test_current_file, { desc = 'Zig DAP test' })
	vim.keymap.set('n', '<leader>za', M.attach_pid, { desc = 'Zig DAP attach' })
end

return M
