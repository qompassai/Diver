-- ~/.config/nvim/lua/dap/zig.lua
-- Qompass AI Diver Zig DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- --------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv
local M = {}
local FILETYPES = {
	zig = true,
}
local FILETYPE_PATTERNS = {
	'zig',
}
local FILE_PATTERNS = {
	'*.zig',
}
local CONFIGURED_FLAG = 'qompass_zig_dap_configured'
local MASON_ROOT = vim.fs.joinpath(fn.stdpath('data'), 'mason')
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
---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.zig',
	})
end
---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
	return fn.input(prompt, default or '', completion or '')
end
---@param command string
---@return boolean
local function executable(command)
	return command ~= '' and fn.executable(command) == 1
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
local function is_file(path)
	local stat = fs_stat(path)
	return stat ~= nil and stat.type == 'file'
end

---@param path string
---@return boolean
local function is_dir(path)
	local stat = fs_stat(path)
	return stat ~= nil and stat.type == 'directory'
end

---@param path string
---@return boolean
local function is_executable_file(path)
	return is_file(path) and executable(path)
end

---@param command string
---@param candidates? string[]
---@return string?
local function resolve_executable(command, candidates)
	local from_path = fn.exepath(command)
	if from_path ~= '' and is_executable_file(from_path) then
		return from_path
	end

	for _, candidate in ipairs(candidates or {}) do
		if is_executable_file(candidate) then
			return candidate
		end
	end

	return nil
end

---@param value string
---@return string
local function absolute_path(value)
	return vim.fs.normalize(fn.fnamemodify(value, ':p'))
end

---@param bufnr integer
---@return string
local function buffer_file(bufnr)
	return api.nvim_buf_get_name(bufnr)
end

---@param bufnr integer
---@return boolean
local function filename_matches(bufnr)
	local name = buffer_file(bufnr):lower()

	for _, pattern in ipairs(FILE_PATTERNS) do
		local suffix = pattern:match('^%*(%..+)$')
		if suffix and name:sub(-#suffix) == suffix:lower() then
			return true
		end
	end

	return false
end

---@param bufnr integer
---@return boolean
local function is_zig_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end

	return FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(bufnr)
end

---@return integer?
local function current_zig_buffer()
	local bufnr = api.nvim_get_current_buf()
	if is_zig_buffer(bufnr) then
		return bufnr
	end

	notify('Zig DAP is available only in Zig buffers', vim.log.levels.ERROR)
	return nil
end

---@param bufnr integer
---@return boolean
local function update_buffer(bufnr)
	local path = buffer_file(bufnr)
	if path == '' then
		notify('Save the Zig buffer before building or debugging', vim.log.levels.ERROR)
		return false
	end

	if not vim.bo[bufnr].modified then
		return true
	end

	local ok, err = pcall(api.nvim_buf_call, bufnr, function()
		vim.cmd('silent update')
	end)
	if not ok then
		notify('Unable to save the Zig buffer: ' .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param bufnr integer
---@return string
local function workspace_root(bufnr)
	local path = buffer_file(bufnr)
	if path == '' then
		return fn.getcwd()
	end

	return vim.fs.root(path, {
		'build.zig',
		'build.zig.zon',
		'.git',
	}) or vim.fs.dirname(path) or fn.getcwd()
end

---@param bufnr integer
---@return boolean
local function has_build_file(bufnr)
	return is_file(vim.fs.joinpath(workspace_root(bufnr), 'build.zig'))
end

---@param bufnr integer
---@return string
local function project_name(bufnr)
	return fn.fnamemodify(workspace_root(bufnr), ':t')
end

---@param bufnr integer
---@return string
local function zig_out_bin(bufnr)
	return vim.fs.joinpath(workspace_root(bufnr), 'zig-out', 'bin')
end

---@param bufnr integer
---@return string
local function dap_cache_dir(bufnr)
	local identity = workspace_root(bufnr) .. '\0' .. buffer_file(bufnr)
	local digest = fn.sha256(identity):sub(1, 16)

	return vim.fs.joinpath(fn.stdpath('cache'), 'qompass-dap', 'zig', digest)
end

---@param path string
---@return boolean
local function ensure_dir(path)
	if is_dir(path) then
		return true
	end

	if fn.mkdir(path, 'p') == -1 or not is_dir(path) then
		notify('Unable to create Zig DAP cache directory: ' .. path, vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param value string
---@return string
local function safe_filename(value)
	local result = value:gsub('[^%w._-]', '_')
	return result ~= '' and result or 'zig-debug'
end

---@param value string?
---@return string
local function trim(value)
	return type(value) == 'string' and vim.trim(value) or ''
end

---@param result vim.SystemCompleted
---@param fallback string
---@return string
local function command_error(result, fallback)
	local message = trim(result.stderr)
	if message == '' then
		message = trim(result.stdout)
	end
	if message == '' then
		message = fallback
	end

	if #message > 6000 then
		message = message:sub(1, 6000) .. '\n…output truncated'
	end

	return message
end

---@param bufnr integer
---@param command string[]
---@return vim.SystemCompleted?
local function run_zig(bufnr, command)
	local zig = resolve_executable('zig', {
		'/usr/bin/zig',
		'/usr/local/bin/zig',
	})
	if not zig then
		notify('zig was not found in PATH', vim.log.levels.ERROR)
		return nil
	end

	command[1] = zig
	return vim.system(command, {
		cwd = workspace_root(bufnr),
		text = true,
	}):wait()
end

---@param raw string
---@return string[]?, string?
local function parse_args(raw)
	local args = {}
	local current = {}
	local quote
	local escaped = false
	local started = false

	local function append(value)
		current[#current + 1] = value
		started = true
	end

	local function finish()
		if started then
			args[#args + 1] = table.concat(current)
			current = {}
			started = false
		end
	end

	for index = 1, #raw do
		local character = raw:sub(index, index)

		if escaped then
			append(character)
			escaped = false
		elseif quote == "'" then
			if character == "'" then
				quote = nil
			else
				append(character)
			end
		elseif quote == '"' then
			if character == '"' then
				quote = nil
			elseif character == '\\' then
				escaped = true
				started = true
			else
				append(character)
			end
		elseif character == '\\' then
			escaped = true
			started = true
		elseif character == "'" or character == '"' then
			quote = character
			started = true
		elseif character:match('%s') then
			finish()
		else
			append(character)
		end
	end

	if escaped then
		return nil, 'Arguments end with an incomplete escape'
	end
	if quote then
		return nil, 'Arguments contain an unterminated quote'
	end

	finish()
	return args, nil
end

---@return string[]?
local function prompt_args()
	local args, err = parse_args(input('Arguments: ', ''))
	if not args then
		notify(err or 'Invalid arguments', vim.log.levels.ERROR)
		return nil
	end

	return args
end

---@param value string
---@return boolean
local function valid_single_line(value)
	return not value:find('[\r\n%z]')
end

---@return table<string, string>?
local function prompt_env()
	local env = {}

	while true do
		local key = input('Environment key (blank to finish): ', '')
		if key == '' then
			return env
		end

		if not key:match('^[%a_][%w_]*$') then
			notify('Invalid environment variable name: ' .. key, vim.log.levels.ERROR)
			return nil
		end

		local value = input('Value for ' .. key .. ': ', '')
		if not valid_single_line(value) then
			notify('Environment values must be single-line strings', vim.log.levels.ERROR)
			return nil
		end

		env[key] = value
	end
end

---@param items string[]
---@param prompt string
---@return string?
local function choose(items, prompt)
	if #items == 0 then
		return nil
	end
	if #items == 1 then
		return items[1]
	end

	local choices = { prompt }
	for index, item in ipairs(items) do
		local relative = item:gsub('^' .. vim.pesc(fn.getcwd() .. '/'), '')
		choices[#choices + 1] = string.format('%d. %s', index, relative)
	end

	local choice = fn.inputlist(choices)
	if choice < 1 or choice > #items then
		return nil
	end

	return items[choice]
end

---@param directory string
---@return string[]
local function scan_executables(directory)
	if not is_dir(directory) then
		return {}
	end

	local scanner = uv.fs_scandir(directory)
	if not scanner then
		return {}
	end

	local programs = {}
	while true do
		local name, kind = uv.fs_scandir_next(scanner)
		if not name then
			break
		end

		if kind == 'file' or kind == 'link' then
			local path = vim.fs.joinpath(directory, name)
			if is_executable_file(path) then
				programs[#programs + 1] = path
			end
		end
	end

	table.sort(programs)
	return programs
end

---@param bufnr integer
---@return string[]
local function candidate_programs(bufnr)
	local programs = {}
	local output_dir = zig_out_bin(bufnr)
	local expected = vim.fs.joinpath(output_dir, project_name(bufnr))

	if is_executable_file(expected) then
		programs[#programs + 1] = expected
	end

	for _, path in ipairs(scan_executables(output_dir)) do
		if not vim.tbl_contains(programs, path) then
			programs[#programs + 1] = path
		end
	end

	return programs
end

---@param bufnr integer
---@return string?
local function resolve_program(bufnr)
	local programs = candidate_programs(bufnr)
	local selected = choose(programs, 'Zig executable:')
	if selected then
		return selected
	end

	local value = input('Path to Zig executable: ', zig_out_bin(bufnr) .. '/', 'file')
	if value == '' then
		return nil
	end

	local program = absolute_path(value)
	if not is_executable_file(program) then
		notify('Zig executable was not found or is not executable', vim.log.levels.ERROR)
		return nil
	end

	return program
end

---@param bufnr integer
---@param optimize 'Debug'|'ReleaseSafe'
---@param suffix? string
---@return string?
local function compile_current_file(bufnr, optimize, suffix)
	local file = buffer_file(bufnr)
	if not is_file(file) then
		notify('Current Zig file was not found', vim.log.levels.ERROR)
		return nil
	end

	local output_dir = dap_cache_dir(bufnr)
	if not ensure_dir(output_dir) then
		return nil
	end

	local basename = safe_filename(fn.fnamemodify(file, ':t:r'))
	local program = vim.fs.joinpath(output_dir, basename .. (suffix or ''))
	local result = run_zig(bufnr, {
		'zig',
		'build-exe',
		file,
		'-O',
		optimize,
		'-femit-bin=' .. program,
	})
	if not result then
		return nil
	end
	if result.code ~= 0 then
		notify(command_error(result, 'Zig compilation failed'), vim.log.levels.ERROR)
		return nil
	end
	if not is_executable_file(program) then
		notify('Compiled Zig executable was not created: ' .. program, vim.log.levels.ERROR)
		return nil
	end

	return program
end

---@param bufnr integer
---@param optimize 'Debug'|'ReleaseSafe'
---@return boolean
local function build_project(bufnr, optimize)
	local command = { 'zig', 'build' }
	if optimize ~= 'Debug' then
		command[#command + 1] = '-Doptimize=' .. optimize
	end

	local result = run_zig(bufnr, command)
	if not result then
		return false
	end
	if result.code ~= 0 then
		notify(command_error(result, 'zig build failed'), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@return { name: string, command: string }?
local function resolve_adapter()
	local primary = resolve_executable(M.adapters.primary.command, {
		'/usr/bin/lldb-dap',
		'/usr/local/bin/lldb-dap',
		vim.fs.joinpath(MASON_ROOT, 'bin', 'lldb-dap'),
	})
	if primary then
		M.adapters.primary.command = primary
		return M.adapters.primary
	end

	local fallback = resolve_executable(M.adapters.fallback.command, {
		vim.fs.joinpath(MASON_ROOT, 'bin', 'codelldb'),
		vim.fs.joinpath(MASON_ROOT, 'packages', 'codelldb', 'extension', 'adapter', 'codelldb'),
		'/usr/bin/codelldb',
		'/usr/local/bin/codelldb',
	})
	if fallback then
		M.adapters.fallback.command = fallback
		return M.adapters.fallback
	end

	notify('No Zig-capable adapter was found. On Arch Linux, install lldb for lldb-dap.', vim.log.levels.ERROR)
	return nil
end

---@param bufnr integer
---@param config table
local function start(bufnr, config)
	if not is_zig_buffer(bufnr) then
		notify('Zig DAP is available only in Zig buffers', vim.log.levels.ERROR)
		return
	end
	if not update_buffer(bufnr) then
		return
	end

	local adapter = resolve_adapter()
	if not adapter then
		return
	end

	config.type = adapter.name
	config.cwd = config.cwd or workspace_root(bufnr)
	if adapter.name == 'lldb-dap' then
		config.debuggerRoot = config.debuggerRoot or workspace_root(bufnr)
	else
		config.sourceLanguages = config.sourceLanguages or { 'zig' }
	end

	debug.start(config)
end

---@param bufnr integer
---@param program string
---@param name string
local function launch_program(bufnr, program, name)
	if not is_executable_file(program) then
		notify('Zig executable was not found or is not executable', vim.log.levels.ERROR)
		return
	end

	local args = prompt_args()
	if args == nil then
		return
	end

	local env = prompt_env()
	if env == nil then
		return
	end

	start(bufnr, {
		request = 'launch',
		name = name,
		program = program,
		args = args,
		env = env,
		stopOnEntry = false,
	})
end

function M.build()
	local bufnr = current_zig_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	if has_build_file(bufnr) then
		if build_project(bufnr, 'Debug') then
			notify('zig build completed')
		end
		return
	end

	local program = compile_current_file(bufnr, 'Debug')
	if program then
		notify('Zig file compiled: ' .. program)
	end
end

function M.build_release()
	local bufnr = current_zig_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	if has_build_file(bufnr) then
		if build_project(bufnr, 'ReleaseSafe') then
			notify('zig build -Doptimize=ReleaseSafe completed')
		end
		return
	end

	local program = compile_current_file(bufnr, 'ReleaseSafe', '-release-safe')
	if program then
		notify('ReleaseSafe Zig file compiled: ' .. program)
	end
end

function M.launch()
	local bufnr = current_zig_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	local program
	if has_build_file(bufnr) then
		if not build_project(bufnr, 'Debug') then
			return
		end
		program = resolve_program(bufnr)
	else
		program = compile_current_file(bufnr, 'Debug')
	end

	if program then
		launch_program(bufnr, program, 'Zig launch')
	end
end

function M.launch_current_binary()
	local bufnr = current_zig_buffer()
	if not bufnr then
		return
	end

	local value = input('Path to Zig executable: ', zig_out_bin(bufnr) .. '/', 'file')
	if value == '' then
		return
	end

	launch_program(bufnr, absolute_path(value), 'Zig launch executable')
end

function M.test_current_file()
	local bufnr = current_zig_buffer()
	if not bufnr or not update_buffer(bufnr) then
		return
	end

	local file = buffer_file(bufnr)
	if not is_file(file) then
		notify('Current Zig file was not found', vim.log.levels.ERROR)
		return
	end

	local output_dir = dap_cache_dir(bufnr)
	if not ensure_dir(output_dir) then
		return
	end

	local basename = safe_filename(fn.fnamemodify(file, ':t:r'))
	local program = vim.fs.joinpath(output_dir, basename .. '-test')
	local result = run_zig(bufnr, {
		'zig',
		'test',
		file,
		'-O',
		'Debug',
		'--test-no-exec',
		'-femit-bin=' .. program,
	})
	if not result then
		return
	end
	if result.code ~= 0 then
		notify(command_error(result, 'Zig test compilation failed'), vim.log.levels.ERROR)
		return
	end
	if not is_executable_file(program) then
		notify('Compiled Zig test executable was not created', vim.log.levels.ERROR)
		return
	end

	launch_program(bufnr, program, 'Zig test current file')
end

function M.attach_pid()
	local bufnr = current_zig_buffer()
	if not bufnr then
		return
	end

	local pid = tonumber(input('PID: ', ''))
	if not pid or pid < 1 or pid % 1 ~= 0 then
		notify('PID must be a positive integer', vim.log.levels.ERROR)
		return
	end
	pid = math.floor(pid)
	---@cast pid integer

	local config = {
		request = 'attach',
		name = 'Zig attach PID',
		pid = pid,
	}

	local program = input('Path to Zig executable (optional): ', zig_out_bin(bufnr) .. '/', 'file')
	if program ~= '' then
		program = absolute_path(program)
		if not is_executable_file(program) then
			notify('Zig executable was not found or is not executable', vim.log.levels.ERROR)
			return
		end
		config.program = program
	end

	start(bufnr, config)
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_zig_buffer(bufnr) or vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end

	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, 'ZigDapBuild', M.build, {
		desc = 'Build the current Zig project or file',
	})
	api.nvim_buf_create_user_command(bufnr, 'ZigDapBuildRelease', M.build_release, {
		desc = 'Build Zig with ReleaseSafe optimization',
	})
	api.nvim_buf_create_user_command(bufnr, 'ZigDapLaunch', M.launch, {
		desc = 'Build and debug Zig',
	})
	api.nvim_buf_create_user_command(bufnr, 'ZigDapExec', M.launch_current_binary, {
		desc = 'Debug a selected Zig executable',
	})
	api.nvim_buf_create_user_command(bufnr, 'ZigDapTest', M.test_current_file, {
		desc = 'Build and debug tests from the current Zig file',
	})
	api.nvim_buf_create_user_command(bufnr, 'ZigDapAttach', M.attach_pid, {
		desc = 'Attach LLDB to a Zig process',
	})

	local map_options = function(description)
		return {
			buffer = bufnr,
			desc = description,
			silent = true,
		}
	end

	vim.keymap.set('n', '<leader>dzb', M.build, map_options('Zig DAP build'))
	vim.keymap.set('n', '<leader>dzB', M.build_release, map_options('Zig DAP ReleaseSafe build'))
	vim.keymap.set('n', '<leader>dzr', M.launch, map_options('Zig DAP launch'))
	vim.keymap.set('n', '<leader>dze', M.launch_current_binary, map_options('Zig DAP executable'))
	vim.keymap.set('n', '<leader>dzt', M.test_current_file, map_options('Zig DAP test'))
	vim.keymap.set('n', '<leader>dza', M.attach_pid, map_options('Zig DAP attach'))
end

local setup_done = false

function M.setup()
	if setup_done then
		return
	end
	setup_done = true

	local group = api.nvim_create_augroup('QompassZigDap', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Zig DAP for Zig filetypes',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = 'Enable Zig DAP for Zig files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
