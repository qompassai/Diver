-- ~/.config/nvim/lua/dap/android.lua
-- Qompass AI Diver Android DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv
local M = {}
local FILETYPES = {
	java = true,
	kotlin = true,
}
local FILETYPE_PATTERNS = {
	'java',
	'kotlin',
}
local FILE_PATTERNS = {
	'*.java',
	'*.kt',
	'*.kts',
}
local CONFIGURED_FLAG = 'android_dap_configured'
M.adapters = {
	adb = {
		command = 'adb',
	},
	jdb = {
		command = 'jdb',
	},
	lldb = {
		command = 'lldb-dap',
	},
}
local selected_device ---@type string?
local managed_forwards = {} ---@type table<string, { serial: string, local_spec: string }>

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.android',
	})
end
---@param command string
---@return boolean
local function executable(command)
	return fn.executable(command) == 1
end

---@param path string
---@return boolean
local function file_exists(path)
	return path ~= '' and uv.fs_stat(path) ~= nil
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

---@param value string?
---@return string[]
local function split_lines(value)
	if type(value) ~= 'string' or value == '' then
		return {}
	end

	return vim.split(value, '\n', {
		plain = true,
		trimempty = true,
	})
end
---@param command string[]
---@param run_cwd? string
---@return integer, string, string
local function system(command, run_cwd)
	local result = vim.system(command, {
		cwd = run_cwd,
		text = true,
	}):wait()

	return result.code, result.stdout or '', result.stderr or ''
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

---@param path string
---@param patterns string[]
---@return boolean
local function file_contains(path, patterns)
	if not file_exists(path) then
		return false
	end

	local ok, lines = pcall(fn.readfile, path)
	if not ok then
		return false
	end

	for _, line in ipairs(lines) do
		for _, pattern in ipairs(patterns) do
			if line:match(pattern) then
				return true
			end
		end
	end

	return false
end

---@param file string
---@return string?
local function manifest_above(file)
	local start = vim.fs.dirname(file)
	if not start then
		return nil
	end

	return vim.fs.find('AndroidManifest.xml', {
		path = start,
		upward = true,
		type = 'file',
	})[1]
end

---@param file string
---@param gradle_root string?
---@param module_root string?
---@return boolean
local function gradle_declares_android(file, gradle_root, module_root)
	local candidates = {}

	local function add(path)
		if path then
			candidates[#candidates + 1] = path
		end
	end

	if file:match('build%.gradle%.kts$') or file:match('build%.gradle$') then
		add(file)
	end

	if module_root then
		add(vim.fs.joinpath(module_root, 'build.gradle'))
		add(vim.fs.joinpath(module_root, 'build.gradle.kts'))
	end

	if gradle_root then
		add(vim.fs.joinpath(gradle_root, 'build.gradle'))
		add(vim.fs.joinpath(gradle_root, 'build.gradle.kts'))
		add(vim.fs.joinpath(gradle_root, 'app', 'build.gradle'))
		add(vim.fs.joinpath(gradle_root, 'app', 'build.gradle.kts'))
	end

	local patterns = {
		'com%.android%.application',
		'com%.android%.library',
		'com%.android%.dynamic%-feature',
		'com%.android%.test',
	}

	local seen = {}
	for _, candidate in ipairs(candidates) do
		if candidate and not seen[candidate] then
			seen[candidate] = true
			if file_contains(candidate, patterns) then
				return true
			end
		end
	end

	return false
end

---@param bufnr integer
---@return string?
local function android_project_root(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	local file = buffer_file(bufnr)
	if file == '' then
		return nil
	end

	local gradle_root = vim.fs.root(file, {
		'settings.gradle',
		'settings.gradle.kts',
		'gradlew',
	})
	local module_root = vim.fs.root(file, {
		'build.gradle',
		'build.gradle.kts',
	})
	local manifest = manifest_above(file)

	if manifest then
		return gradle_root or module_root or vim.fs.dirname(manifest)
	end

	if gradle_declares_android(file, gradle_root, module_root) then
		return gradle_root or module_root
	end

	return nil
end

---@param bufnr integer
---@return boolean
local function is_android_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end
	local applicable_file = FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(bufnr)
	return applicable_file and android_project_root(bufnr) ~= nil
end

---@return integer?, string?
local function current_android_context()
	local bufnr = api.nvim_get_current_buf()
	if not is_android_buffer(bufnr) then
		notify('Android DAP is available only in Android Java/Kotlin buffers', vim.log.levels.ERROR)
		return nil, nil
	end

	local root = android_project_root(bufnr)
	if not root then
		notify('Unable to resolve the Android project root', vim.log.levels.ERROR)
		return nil, nil
	end

	return bufnr, root
end

---@param ... string
---@return string[]
local function adb(...)
	return {
		M.adapters.adb.command,
		...,
	}
end

---@param serial string
---@param ... string
---@return string[]
local function adb_shell(serial, ...)
	return {
		M.adapters.adb.command,
		'-s',
		serial,
		'shell',
		...,
	}
end

---@return boolean
local function ensure_adb()
	if executable(M.adapters.adb.command) then
		return true
	end
	notify('adb not found in PATH', vim.log.levels.ERROR)
	return false
end
local function ensure_jdb() ---@return boolean
	if executable(M.adapters.jdb.command) then
		return true
	end
	notify('jdb not found in PATH', vim.log.levels.ERROR)
	return false
end
---@return boolean
local function ensure_lldb()
	if executable(M.adapters.lldb.command) then
		return true
	end
	notify('lldb-dap not found in PATH', vim.log.levels.ERROR)
	return false
end
---@return string[]
local function connected_devices()
	if not ensure_adb() then
		return {}
	end
	local code, stdout, stderr = system(adb('devices'))
	if code ~= 0 then
		notify(trim(stderr) ~= '' and trim(stderr) or 'adb devices failed', vim.log.levels.ERROR)
		return {}
	end
	local devices = {}
	for _, line in ipairs(split_lines(stdout)) do
		local serial, state = line:match('^(%S+)%s+(%S+)')
		if serial and state == 'device' then
			devices[#devices + 1] = serial
		end
	end
	table.sort(devices)
	return devices
end
---@return string?
local function choose_device()
	local devices = connected_devices()
	if #devices == 0 then
		notify('No authorized Android devices or emulators detected', vim.log.levels.WARN)
		selected_device = nil
		return nil
	end
	if selected_device and vim.list_contains(devices, selected_device) then
		return selected_device
	end
	selected_device = pick(devices, 'Android device:')
	return selected_device
end
---@param value string
---@return boolean
local function valid_qualified_name(value)
	if value == '' or value:sub(1, 1) == '.' or value:sub(-1) == '.' or value:find('..', 1, true) then
		return false
	end

	local count = 0
	for segment in value:gmatch('[^.]+') do
		if not segment:match('^[%a_][%w_]*$') then
			return false
		end
		count = count + 1
	end
	return count > 0
end

---@param activity string
---@return boolean
local function valid_activity_name(activity)
	if activity == '' then
		return true
	end
	local normalized = activity:sub(1, 1) == '.' and activity:sub(2) or activity
	return valid_qualified_name(normalized)
end
---@param root string
---@param bufnr integer
---@return string[]
local function gradle_candidates(root, bufnr)
	local file = buffer_file(bufnr)
	local module_root = vim.fs.root(file, {
		'build.gradle',
		'build.gradle.kts',
	})
	local candidates = {}
	if module_root then
		candidates[#candidates + 1] = vim.fs.joinpath(module_root, 'build.gradle')
		candidates[#candidates + 1] = vim.fs.joinpath(module_root, 'build.gradle.kts')
	end
	candidates[#candidates + 1] = vim.fs.joinpath(root, 'app', 'build.gradle')
	candidates[#candidates + 1] = vim.fs.joinpath(root, 'app', 'build.gradle.kts')
	candidates[#candidates + 1] = vim.fs.joinpath(root, 'build.gradle')
	candidates[#candidates + 1] = vim.fs.joinpath(root, 'build.gradle.kts')
	local results = {}
	local seen = {}
	for _, candidate in ipairs(candidates) do
		if candidate and not seen[candidate] then
			seen[candidate] = true
			results[#results + 1] = candidate
		end
	end
	return results
end

---@param root string
---@param bufnr integer
---@return string?
local function package_from_gradle(root, bufnr)
	for _, file in ipairs(gradle_candidates(root, bufnr)) do
		if file_exists(file) then
			for _, line in ipairs(fn.readfile(file)) do
				local package_name = line:match([[applicationId%s*=?%s*"([^"]+)"]])
					or line:match([[applicationId%s*=?%s*'([^']+)']])
					or line:match([[namespace%s*=?%s*"([^"]+)"]])
					or line:match([[namespace%s*=?%s*'([^']+)']])
				if package_name and valid_qualified_name(package_name) then
					return package_name
				end
			end
		end
	end
	return nil
end
---@param root string
---@param bufnr integer
---@return string?
local function package_from_manifest(root, bufnr)
	local file = buffer_file(bufnr)
	local candidates = {}
	local nearby_manifest = manifest_above(file)
	if nearby_manifest then
		candidates[#candidates + 1] = nearby_manifest
	end
	candidates[#candidates + 1] = vim.fs.joinpath(root, 'app', 'src', 'main', 'AndroidManifest.xml')
	candidates[#candidates + 1] = vim.fs.joinpath(root, 'src', 'main', 'AndroidManifest.xml')
	local seen = {}
	for _, manifest in ipairs(candidates) do
		if manifest and not seen[manifest] and file_exists(manifest) then
			seen[manifest] = true
			for _, line in ipairs(fn.readfile(manifest)) do
				local package_name = line:match([[package%s*=%s*"([^"]+)"]]) or line:match([[package%s*=%s*'([^']+)']])
				if package_name and valid_qualified_name(package_name) then
					return package_name
				end
			end
		end
	end

	return nil
end

---@param root string
---@param bufnr integer
---@return string?
local function resolve_package_name(root, bufnr)
	local guessed = package_from_gradle(root, bufnr) or package_from_manifest(root, bufnr) or ''
	local package_name = input('Android package: ', guessed)
	if package_name == '' then
		return nil
	end
	if not valid_qualified_name(package_name) then
		notify('Invalid Android package name', vim.log.levels.ERROR)
		return nil
	end
	return package_name
end
---@return string?
local function resolve_activity()
	local activity = input('Launch activity (optional, for example .MainActivity): ')
	if not valid_activity_name(activity) then
		notify('Invalid Android activity name', vim.log.levels.ERROR)
		return nil
	end
	return activity
end
---@param default integer
---@return integer?
local function resolve_port(default)
	local value = tonumber(input('Local TCP port: ', tostring(default)))
	if not value or value < 1 or value > 65535 or value % 1 ~= 0 then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return nil
	end
	return math.floor(value)
end
---@param serial string
---@return string[]
local function list_jdwp(serial)
	local code, stdout, stderr = system(adb('-s', serial, 'jdwp'))
	if code ~= 0 then
		notify(trim(stderr) ~= '' and trim(stderr) or 'adb jdwp failed', vim.log.levels.ERROR)
		return {}
	end
	local pids = {}
	for _, line in ipairs(split_lines(stdout)) do
		local pid = trim(line)
		if pid:match('^%d+$') then
			pids[#pids + 1] = pid
		end
	end
	return pids
end
---@param value string|number|nil
---@return integer?
local function positive_integer(value)
	local parsed = tonumber(value)
	if not parsed or parsed < 1 or parsed % 1 ~= 0 then
		return nil
	end
	local result = math.floor(parsed)
	---@cast result integer
	return result
end
---@param serial string
---@param package_name string
---@return integer?
local function pid_for_package(serial, package_name)
	local code, stdout = system(adb_shell(serial, 'pidof', package_name))
	if code == 0 then
		local pid = positive_integer(trim(stdout):match('^(%d+)'))
		if pid then
			return pid
		end
	end
	local ps_code, ps_stdout = system(adb_shell(serial, 'ps', '-A'))
	if ps_code ~= 0 then
		return nil
	end
	for _, line in ipairs(split_lines(ps_stdout)) do
		local columns = vim.split(trim(line), '%s+', {
			trimempty = true,
		})
		local process_name = columns[#columns]
		if
			process_name == package_name
			or (type(process_name) == 'string' and vim.startswith(process_name, package_name .. ':'))
		then
			local pid = positive_integer(columns[2])
			if pid then
				return pid
			end
		end
	end
	return nil
end
---@param serial string
---@param local_spec string
local function remember_forward(serial, local_spec)
	local key = serial .. '\0' .. local_spec
	managed_forwards[key] = {
		serial = serial,
		local_spec = local_spec,
	}
end
---@param silent? boolean
local function remove_managed_forwards(silent)
	if not executable(M.adapters.adb.command) then
		if not silent then
			notify('adb not found in PATH', vim.log.levels.ERROR)
		end
		return
	end
	local removed = 0
	for key, forward in pairs(managed_forwards) do
		local code, _, stderr = system(adb('-s', forward.serial, 'forward', '--remove', forward.local_spec))
		if code == 0 then
			managed_forwards[key] = nil
			removed = removed + 1
		elseif not silent then
			notify(
				trim(stderr) ~= '' and trim(stderr) or ('Failed to remove ' .. forward.local_spec),
				vim.log.levels.ERROR
			)
		end
	end
	if not silent then
		notify(('Removed %d Android DAP forward(s)'):format(removed))
	end
end
---@param root string
---@param filetype string
---@param command string[]
---@return integer?
local function open_terminal(root, filetype, command)
	vim.cmd('botright new')
	local bufnr = api.nvim_get_current_buf()
	local job = fn.jobstart(command, {
		cwd = root,
		term = true,
	})
	if job <= 0 then
		notify('Failed to start terminal job', vim.log.levels.ERROR)
		api.nvim_buf_delete(bufnr, { force = true })
		return nil
	end
	vim.bo[bufnr].bufhidden = 'wipe'
	vim.bo[bufnr].filetype = filetype
	vim.bo[bufnr].swapfile = false
	vim.cmd.startinsert()
	return job
end
---@class AndroidJdwpForward
---@field serial string
---@field package_name string
---@field pid integer
---@field port integer

---@param root string
---@param bufnr integer
---@return AndroidJdwpForward?
local function forward_jdwp(root, bufnr)
	local serial = choose_device()
	if not serial then
		return nil
	end

	local package_name = resolve_package_name(root, bufnr)
	if not package_name then
		return nil
	end

	local pid = pid_for_package(serial, package_name)
	if not pid then
		local selected = pick(list_jdwp(serial), 'JDWP PID:')
		pid = positive_integer(selected)
	end

	if not pid then
		notify('No valid JDWP process selected', vim.log.levels.WARN)
		return nil
	end

	local port = resolve_port(8700)
	if not port then
		return nil
	end
	local local_spec = ('tcp:%d'):format(port)
	local code, _, stderr = system(adb('-s', serial, 'forward', local_spec, ('jdwp:%d'):format(pid)))
	if code ~= 0 then
		notify(trim(stderr) ~= '' and trim(stderr) or 'adb forward failed', vim.log.levels.ERROR)
		return nil
	end
	remember_forward(serial, local_spec)
	notify(string.format('Forwarded localhost:%d to jdwp:%d (%s)', port, pid, package_name))
	return {
		serial = serial,
		package_name = package_name,
		pid = pid,
		port = port,
	}
end
function M.select_device()
	local bufnr = current_android_context()
	if not bufnr then
		return
	end
	selected_device = nil
	local serial = choose_device()
	if serial then
		notify('Using Android device: ' .. serial)
	end
end
function M.launch_app()
	local bufnr, root = current_android_context()
	if not bufnr or not root or not ensure_adb() then
		return
	end
	local serial = choose_device()
	if not serial then
		return
	end
	local package_name = resolve_package_name(root, bufnr)
	if not package_name then
		return
	end
	local activity = resolve_activity()
	if activity == nil then
		return
	end
	local command
	if activity ~= '' then
		local component
		if activity:sub(1, 1) == '.' then
			component = package_name .. '/' .. activity
		elseif activity:find('.', 1, true) then
			component = package_name .. '/' .. activity
		else
			component = package_name .. '/' .. package_name .. '.' .. activity
		end
		command = adb_shell(serial, 'am', 'start', '-D', '-n', component)
	else
		local debug_code, _, debug_stderr = system(adb_shell(serial, 'am', 'set-debug-app', '-w', package_name))
		if debug_code ~= 0 then
			notify(
				trim(debug_stderr) ~= '' and trim(debug_stderr) or 'Failed to mark the Android app for debugging',
				vim.log.levels.ERROR
			)
			return
		end
		command = adb_shell(serial, 'monkey', '-p', package_name, '-c', 'android.intent.category.LAUNCHER', '1')
	end
	local code, stdout, stderr = system(command)
	if code ~= 0 then
		notify(trim(stderr) ~= '' and trim(stderr) or 'Failed to launch Android app', vim.log.levels.ERROR)
		return
	end
	notify(('Launched %s on %s'):format(package_name, serial))
	if trim(stdout) ~= '' then
		notify(trim(stdout))
	end
end
function M.clear_debug_app()
	local bufnr = current_android_context()
	if not bufnr or not ensure_adb() then
		return
	end
	local serial = choose_device()
	if not serial then
		return
	end
	local code, _, stderr = system(adb_shell(serial, 'am', 'clear-debug-app'))
	if code ~= 0 then
		notify(trim(stderr) ~= '' and trim(stderr) or 'Failed to clear the Android debug app', vim.log.levels.ERROR)
		return
	end

	notify('Cleared Android wait-for-debugger state on ' .. serial)
end

function M.forward_jdwp()
	local bufnr, root = current_android_context()
	if not bufnr or not root or not ensure_adb() then
		return
	end
	forward_jdwp(root, bufnr)
end
function M.attach_jdb()
	local bufnr, root = current_android_context()
	if not bufnr or not root or not ensure_adb() or not ensure_jdb() then
		return
	end
	local forward = forward_jdwp(root, bufnr)
	if not forward then
		return
	end
	local job = open_terminal(root, 'jdb', {
		M.adapters.jdb.command,
		'-attach',
		('127.0.0.1:%d'):format(forward.port),
	})
	if job then
		notify(('Started jdb on localhost:%d'):format(forward.port))
	end
end
function M.clear_forwards()
	local bufnr = current_android_context()
	if not bufnr then
		return
	end
	remove_managed_forwards(false)
end
function M.native_attach_lldb()
	local bufnr, root = current_android_context()
	if not bufnr or not root or not ensure_adb() or not ensure_lldb() then
		return
	end
	local serial = choose_device()
	if not serial then
		return
	end
	local package_name = resolve_package_name(root, bufnr)
	if not package_name then
		return
	end
	local pid = pid_for_package(serial, package_name)
	if not pid then
		notify('Could not resolve the Android process for ' .. package_name, vim.log.levels.ERROR)
		return
	end
	local program = input('Local unstripped binary or shared object: ', root .. '/', 'file')
	if not file_exists(program) then
		notify('Local native debug binary not found', vim.log.levels.ERROR)
		return
	end
	local port = resolve_port(5039)
	if not port then
		return
	end
	local local_spec = ('tcp:%d'):format(port)
	local remote_spec = ('localfilesystem:/data/data/%s/debug.socket'):format(package_name)
	local code, _, stderr = system(adb('-s', serial, 'forward', local_spec, remote_spec))
	if code ~= 0 then
		notify(
			trim(stderr) ~= '' and trim(stderr) or 'Native socket forwarding failed; ensure lldb-server is listening',
			vim.log.levels.ERROR
		)
		return
	end
	remember_forward(serial, local_spec)
	debug.start({
		type = 'lldb',
		request = 'attach',
		name = 'Android native attach',
		program = program,
		pid = pid,
		cwd = root,
		initCommands = {
			'platform select remote-android',
			('platform connect connect://127.0.0.1:%d'):format(port),
		},
	})
	notify(string.format('Started LLDB attach for %s (PID %d)', package_name, pid))
end
function M.logcat()
	local bufnr, root = current_android_context()
	if not bufnr or not root or not ensure_adb() then
		return
	end
	local serial = choose_device()
	if not serial then
		return
	end
	local job = open_terminal(root, 'logcat', adb('-s', serial, 'logcat'))
	if job then
		vim.b.android_logcat_job = job
		notify('Streaming logcat for ' .. serial)
	end
end
---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_android_buffer(bufnr) then
		return
	end
	if vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end

	api.nvim_buf_create_user_command(bufnr, 'AndroidSelectDevice', M.select_device, {
		desc = 'Select an Android device or emulator',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidLaunch', M.launch_app, {
		desc = 'Launch the Android app in debug mode',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidClearDebugApp', M.clear_debug_app, {
		desc = 'Clear the Android wait-for-debugger state',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidForwardJdwp', M.forward_jdwp, {
		desc = 'Forward JDWP for Java/Kotlin debugging',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidAttachJdb', M.attach_jdb, {
		desc = 'Forward JDWP and attach jdb',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidClearForwards', M.clear_forwards, {
		desc = 'Remove forwards created by Android DAP',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidNativeAttach', M.native_attach_lldb, {
		desc = 'Attach lldb-dap to an Android native process',
	})
	api.nvim_buf_create_user_command(bufnr, 'AndroidLogcat', M.logcat, {
		desc = 'Stream Android logcat in a terminal buffer',
	})
	vim.b[bufnr][CONFIGURED_FLAG] = true
	api.nvim_exec_autocmds('User', {
		pattern = 'AndroidDapConfigured',
		modeline = false,
		data = {
			bufnr = bufnr,
		},
	})
end
function M.setup()
	local group = api.nvim_create_augroup('dap.android', {
		clear = true,
	})
	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Android DAP for Android Java/Kotlin buffers',
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
		desc = 'Enable Android DAP for Android source files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})
	api.nvim_create_autocmd('VimLeavePre', {
		group = group,
		desc = 'Remove forwards created by Android DAP',
		callback = function()
			remove_managed_forwards(true)
		end,
	})
	configure_buffer(api.nvim_get_current_buf())
end

return M
