-- ~/.config/nvim/lua/dap/kotlin.lua
-- Qompass AI Diver Kotlin/JVM DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------
local api = vim.api
local debug = vim.debug
local fn = vim.fn
local uv = vim.uv
local M = {}
local FILETYPES = {
	kotlin = true,
}
local FILETYPE_PATTERNS = {
	'kotlin',
}
local FILE_PATTERNS = {
	'*.kt',
	'*.kts',
}
local ANDROID_PLUGIN_PATTERNS = {
	'com%.android%.application',
	'com%.android%.library',
	'com%.android%.dynamic%-feature',
	'com%.android%.test',
}
local CONFIGURED_FLAG = 'qompass_kotlin_dap_configured'
local setup_done = false
M.adapter = {
	name = 'kotlin',
	command = 'kotlin-debug-adapter',
}
---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'dap.kotlin',
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
---@param path string
---@return boolean
local function is_dir(path)
	local stat = fs_stat(path)
	return stat ~= nil and stat.type == 'directory'
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
---@return string?
local function module_root(bufnr)
	local file = buffer_file(bufnr)
	if file == '' then
		return nil
	end
	return vim.fs.root(file, {
		'build.gradle.kts',
		'build.gradle',
		'pom.xml',
	})
end
---@param root string
---@return boolean
local function is_android_module(root)
	if file_exists(vim.fs.joinpath(root, 'src', 'main', 'AndroidManifest.xml')) then
		return true
	end
	return file_contains(vim.fs.joinpath(root, 'build.gradle'), ANDROID_PLUGIN_PATTERNS)
		or file_contains(vim.fs.joinpath(root, 'build.gradle.kts'), ANDROID_PLUGIN_PATTERNS)
end
---@param bufnr integer
---@return boolean
local function is_kotlin_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return false
	end
	local applicable_file = FILETYPES[vim.bo[bufnr].filetype] == true or filename_matches(bufnr)
	if not applicable_file then
		return false
	end
	local root = module_root(bufnr)
	return root ~= nil and not is_android_module(root)
end
---@return integer?, string?
local function current_kotlin_context()
	local bufnr = api.nvim_get_current_buf()
	if not api.nvim_buf_is_valid(bufnr) then
		return nil, nil
	end
	local root = module_root(bufnr)
	if root and is_android_module(root) then
		notify('This is an Android Kotlin buffer; use the Android DAP configuration', vim.log.levels.ERROR)
		return nil, nil
	end
	if not is_kotlin_buffer(bufnr) or not root then
		notify('Kotlin DAP is available only in non-Android Kotlin/JVM Gradle or Maven buffers', vim.log.levels.ERROR)
		return nil, nil
	end
	return bufnr, root
end
---@param bufnr integer
---@return boolean
local function update_buffer(bufnr)
	local file = buffer_file(bufnr)
	if file == '' then
		notify('Save the Kotlin buffer before building or debugging', vim.log.levels.ERROR)
		return false
	end
	if not vim.bo[bufnr].modified then
		return true
	end
	local ok, err = pcall(api.nvim_buf_call, bufnr, function()
		vim.cmd('silent update')
	end)

	if not ok then
		notify('Unable to save the Kotlin buffer: ' .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

---@param root string
---@return boolean
local function has_gradle(root)
	return file_exists(vim.fs.joinpath(root, 'build.gradle.kts')) or file_exists(vim.fs.joinpath(root, 'build.gradle'))
end

---@param root string
---@return boolean
local function has_maven(root)
	return file_exists(vim.fs.joinpath(root, 'pom.xml'))
end

---@param root string
---@return string[]
local function main_output_candidates(root)
	return {
		vim.fs.joinpath(root, 'build', 'classes', 'kotlin', 'main'),
		vim.fs.joinpath(root, 'build', 'classes', 'kotlin', 'jvm', 'main'),
		vim.fs.joinpath(root, 'build', 'classes', 'java', 'main'),
		vim.fs.joinpath(root, 'target', 'classes'),
	}
end

---@param root string
---@return string[]
local function test_output_candidates(root)
	return {
		vim.fs.joinpath(root, 'build', 'classes', 'kotlin', 'test'),
		vim.fs.joinpath(root, 'build', 'classes', 'kotlin', 'jvm', 'test'),
		vim.fs.joinpath(root, 'build', 'classes', 'java', 'test'),
		vim.fs.joinpath(root, 'target', 'test-classes'),
	}
end

---@param candidates string[]
---@return boolean
local function any_output_exists(candidates)
	for _, path in ipairs(candidates) do
		if is_dir(path) then
			return true
		end
	end

	return false
end

---@param root string
---@param include_tests? boolean
---@return boolean
local function has_compiled_output(root, include_tests)
	local main_exists = any_output_exists(main_output_candidates(root))
	if not include_tests then
		return main_exists
	end

	return main_exists and any_output_exists(test_output_candidates(root))
end

---@param start string
---@return string?
local function gradle_wrapper(start)
	local wrapper_root = vim.fs.root(start, {
		'gradlew',
	})
	if not wrapper_root then
		return nil
	end

	local wrapper = vim.fs.joinpath(wrapper_root, 'gradlew')
	return file_exists(wrapper) and wrapper or nil
end

---@param root string
---@param include_tests? boolean
---@return string[]?, string?
local function build_command(root, include_tests)
	if has_gradle(root) then
		local task = include_tests and 'testClasses' or 'classes'
		local wrapper = gradle_wrapper(root)

		if wrapper then
			if not executable(wrapper) then
				return nil, ('Gradle wrapper is not executable: %s Run chmod u+x on it.'):format(wrapper)
			end
			return { wrapper, '--no-daemon', task }, nil
		end

		if executable('gradle') then
			return { 'gradle', '--no-daemon', task }, nil
		end

		return nil, 'No executable Gradle wrapper or gradle command was found'
	end

	if has_maven(root) then
		if not executable('mvn') then
			return nil, 'Maven command not found in PATH'
		end

		return {
			'mvn',
			'-DskipTests',
			include_tests and 'test-compile' or 'compile',
		}, nil
	end

	return nil, 'Kotlin DAP requires a Gradle or Maven project'
end

---@param root string
---@param include_tests? boolean
---@return boolean
local function run_build(root, include_tests)
	local command, err = build_command(root, include_tests)
	if not command then
		notify(err or 'Unable to resolve a Kotlin build command', vim.log.levels.ERROR)
		return false
	end

	notify('Running: ' .. table.concat(command, ' '))
	local result = vim.system(command, {
		cwd = root,
		text = true,
	}):wait()

	if result.code ~= 0 then
		local message = result.stderr
		if not message or message == '' then
			message = result.stdout
		end
		if not message or message == '' then
			message = 'Kotlin build failed'
		end

		notify(vim.trim(message), vim.log.levels.ERROR)
		return false
	end

	if not has_compiled_output(root, include_tests) then
		notify(
			'The build completed, but kotlin-debug-adapter-compatible class output was not found',
			vim.log.levels.ERROR
		)
		return false
	end

	return true
end

---@param root string
---@param include_tests? boolean
---@return boolean
local function ensure_built(root, include_tests)
	if has_compiled_output(root, include_tests) then
		return true
	end

	local kind = include_tests and 'test classes' or 'classes'
	local answer = input(('No compiled Kotlin %s found. Build now? [Y/n]: '):format(kind), 'Y')
	if answer:lower() == 'n' then
		notify('Build required before Kotlin debug launch', vim.log.levels.WARN)
		return false
	end

	return run_build(root, include_tests)
end

---@return boolean
local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end

	notify(
		('Kotlin DAP adapter not found: %s. Install fwcd/kotlin-debug-adapter and ensure it is in PATH.'):format(
			M.adapter.command
		),
		vim.log.levels.ERROR
	)
	return false
end

---@param value string
---@return boolean
local function safe_single_line(value)
	return not value:find('[\r\n%z]')
end

---@param file string
---@return string[]?
local function read_lines(file)
	if not file_exists(file) then
		return nil
	end

	local ok, lines = pcall(fn.readfile, file)
	return ok and lines or nil
end

---@param lines string[]
---@return string?
local function package_name(lines)
	for _, line in ipairs(lines) do
		local package = line:match('^%s*package%s+([%w%._]+)')
		if package then
			return package
		end
	end

	return nil
end

---@param lines string[]
---@return string?
local function file_jvm_name(lines)
	for _, line in ipairs(lines) do
		local name = line:match('@file:%s*JvmName%s*%(%s*"([%w_$]+)"%s*%)')
		if name then
			return name
		end
	end

	return nil
end

---@param file string
---@return boolean
local function contains_main(file)
	local lines = read_lines(file)
	if not lines then
		return false
	end

	for _, line in ipairs(lines) do
		if line:match('%f[%a]fun%s+main%s*%(') then
			return true
		end
	end

	return false
end

---@param file string
---@return string?
local function inferred_main_class(file)
	local lines = read_lines(file)
	if not lines then
		return nil
	end

	local class = file_jvm_name(lines) or (fn.fnamemodify(file, ':t:r') .. 'Kt')
	local package = package_name(lines)

	if package and package ~= '' then
		return package .. '.' .. class
	end

	return class
end

---@return string?
local function choose_main_class()
	local bufnr, _ = current_kotlin_context()
	if not bufnr then
		return nil
	end

	local guess = inferred_main_class(buffer_file(bufnr)) or ''
	local main_class = input('Kotlin main class: ', guess)
	if main_class == '' then
		return nil
	end

	if not safe_single_line(main_class) then
		notify('Main class must be a single line', vim.log.levels.ERROR)
		return nil
	end

	return main_class
end

---@param main_class string
---@return string?
local function with_program_args(main_class)
	local args = input('Program args (optional; quote values containing spaces): ')
	if args == '' then
		return main_class
	end

	if not safe_single_line(args) then
		notify('Program arguments must be a single line', vim.log.levels.ERROR)
		return nil
	end

	return main_class .. ' ' .. args
end

---@param bufnr integer
---@param root string
---@param config table
local function start(bufnr, root, config)
	if not is_kotlin_buffer(bufnr) then
		notify('Refusing to start Kotlin DAP outside a Kotlin/JVM buffer', vim.log.levels.ERROR)
		return
	end

	if not update_buffer(bufnr) or not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
	config.projectRoot = root
	config.cwd = config.cwd or root
	debug.start(config)
end

function M.build()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root or not update_buffer(bufnr) then
		return
	end

	if run_build(root, false) then
		notify('Kotlin project build complete')
	end
end

function M.build_tests()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root or not update_buffer(bufnr) then
		return
	end

	if run_build(root, true) then
		notify('Kotlin test classes build complete')
	end
end

function M.launch_main()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root or not update_buffer(bufnr) then
		return
	end

	if not ensure_built(root, false) then
		return
	end

	local main_class = choose_main_class()
	if not main_class then
		notify('Main class is required', vim.log.levels.ERROR)
		return
	end

	local launch_command = with_program_args(main_class)
	if not launch_command then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Kotlin launch main',
		mainClass = launch_command,
		noDebug = false,
	})
end

function M.launch_current_file()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root or not update_buffer(bufnr) then
		return
	end

	local file = buffer_file(bufnr)
	if not file:match('%.kt$') then
		notify('Current-file launch supports compiled .kt files, not Kotlin scripts', vim.log.levels.ERROR)
		return
	end

	if not contains_main(file) then
		notify('No Kotlin main function found in the current file', vim.log.levels.ERROR)
		return
	end

	if not ensure_built(root, false) then
		return
	end

	local main_class = inferred_main_class(file)
	if not main_class then
		notify('Could not infer the current file main class', vim.log.levels.ERROR)
		return
	end

	local launch_command = with_program_args(main_class)
	if not launch_command then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Kotlin launch current file',
		mainClass = launch_command,
		noDebug = false,
	})
end

function M.launch_prompt()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root or not update_buffer(bufnr) then
		return
	end

	if not ensure_built(root, false) then
		return
	end

	local main_class = input('Kotlin main class: ')
	if main_class == '' then
		notify('Main class is required', vim.log.levels.ERROR)
		return
	end

	if not safe_single_line(main_class) then
		notify('Main class must be a single line', vim.log.levels.ERROR)
		return
	end

	local launch_command = with_program_args(main_class)
	if not launch_command then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Kotlin launch prompted main',
		mainClass = launch_command,
		noDebug = false,
	})
end

function M.debug_tests()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root or not update_buffer(bufnr) then
		return
	end

	if not ensure_built(root, true) then
		return
	end

	start(bufnr, root, {
		request = 'launch',
		name = 'Kotlin debug JUnit tests',
		mainClass = 'org.junit.platform.console.ConsoleLauncher --scan-class-path',
		noDebug = false,
	})
end

function M.attach_jdwp()
	local bufnr, root = current_kotlin_context()
	if not bufnr or not root then
		return
	end

	local host = input('Host: ', '127.0.0.1')
	if host == '' then
		host = '127.0.0.1'
	end
	if not safe_single_line(host) then
		notify('Host must be a single line', vim.log.levels.ERROR)
		return
	end

	local raw_port = tonumber(input('Port: ', '5005'))
	if not raw_port or raw_port < 1 or raw_port > 65535 or raw_port % 1 ~= 0 then
		notify('Port must be an integer from 1 through 65535', vim.log.levels.ERROR)
		return
	end

	local raw_timeout = tonumber(input('Attach timeout in milliseconds: ', '5000'))
	if not raw_timeout or raw_timeout < 1 or raw_timeout % 1 ~= 0 then
		notify('Attach timeout must be a positive integer', vim.log.levels.ERROR)
		return
	end

	start(bufnr, root, {
		request = 'attach',
		name = 'Kotlin attach JDWP',
		hostName = host,
		port = math.floor(raw_port),
		timeout = math.floor(raw_timeout),
	})
end

---@param lines string[]
---@param filetype string
local function show_scratch_buffer(lines, filetype)
	vim.cmd('botright new')
	local bufnr = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].bufhidden = 'wipe'
	vim.bo[bufnr].buftype = 'nofile'
	vim.bo[bufnr].filetype = filetype
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = false
end

function M.gradle_debug_hint()
	local _, root = current_kotlin_context()
	if not root then
		return
	end

	show_scratch_buffer({
		'Gradle Kotlin/JVM JDWP examples:',
		'',
		'./gradlew run --debug-jvm',
		'./gradlew test --debug-jvm',
		'',
		'Then use :KotlinDapAttach.',
		'Default endpoint: 127.0.0.1:5005',
		'',
		'Project root:',
		root,
	}, 'markdown')
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_kotlin_buffer(bufnr) then
		return
	end

	if vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end
	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, 'KotlinDapBuild', M.build, {
		desc = 'Build Kotlin/JVM project classes',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinDapBuildTests', M.build_tests, {
		desc = 'Build Kotlin/JVM test classes',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinDapMain', M.launch_main, {
		desc = 'Debug a Kotlin/JVM main class',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinDapFile', M.launch_current_file, {
		desc = 'Debug the current compiled Kotlin file main function',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinDapPrompt', M.launch_prompt, {
		desc = 'Prompt for and debug a Kotlin/JVM main class',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinDapTest', M.debug_tests, {
		desc = 'Debug Kotlin/JVM JUnit tests',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinDapAttach', M.attach_jdwp, {
		desc = 'Attach Kotlin DAP to a JVM JDWP endpoint',
	})
	api.nvim_buf_create_user_command(bufnr, 'KotlinGradleDebugHint', M.gradle_debug_hint, {
		desc = 'Show Gradle JVM debug attach hints',
	})

	local function map(lhs, rhs, description)
		vim.keymap.set('n', lhs, rhs, {
			buffer = bufnr,
			desc = description,
			silent = true,
		})
	end

	map('<leader>dkb', M.build, 'Kotlin DAP build')
	map('<leader>dkB', M.build_tests, 'Kotlin DAP build tests')
	map('<leader>dkm', M.launch_main, 'Kotlin DAP main')
	map('<leader>dkf', M.launch_current_file, 'Kotlin DAP current file')
	map('<leader>dkp', M.launch_prompt, 'Kotlin DAP prompt')
	map('<leader>dkt', M.debug_tests, 'Kotlin DAP tests')
	map('<leader>dka', M.attach_jdwp, 'Kotlin DAP attach')
	map('<leader>dkh', M.gradle_debug_hint, 'Kotlin Gradle debug hint')
end

function M.setup()
	if setup_done then
		configure_buffer(api.nvim_get_current_buf())
		return
	end
	setup_done = true

	local group = api.nvim_create_augroup('qompass.dap.kotlin', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = 'Enable Kotlin DAP for Kotlin/JVM filetypes',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile' }, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = 'Enable Kotlin DAP for Kotlin/JVM files',
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
