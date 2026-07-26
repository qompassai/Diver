-- ~/.config/nvim/lua/dap/kotlin.lua
-- Kotlin DAP configuration for Neovim 0.13 built-in vim.debug, no plugins
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.uv
local debug = vim.debug
local FILETYPES = { kotlin = true }
local FILETYPE_PATTERNS = { 'kotlin' }
local FILE_PATTERNS = { '*.kt', '*.kts' }
local M = {}

M.adapter = {
	name = 'kotlin',
	command = 'kotlin-debug-adapter',
}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = 'dap.kotlin' })
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
		'build.gradle.kts',
		'build.gradle',
		'settings.gradle.kts',
		'settings.gradle',
		'pom.xml',
		'.git',
	})

	return root or cwd()
end

local function has_gradle(root)
	return file_exists(path_join(root, 'build.gradle.kts')) or file_exists(path_join(root, 'build.gradle'))
end

local function has_maven(root)
	return file_exists(path_join(root, 'pom.xml'))
end

local function compiled_output_candidates(root)
	return {
		path_join(root, 'build', 'classes', 'kotlin', 'main'),
		path_join(root, 'build', 'classes', 'java', 'main'),
		path_join(root, 'target', 'classes', 'kotlin', 'main'),
		path_join(root, 'target', 'classes'),
	}
end

local function has_compiled_output(root)
	for _, path in ipairs(compiled_output_candidates(root)) do
		if is_dir(path) then
			return true
		end
	end
	return false
end

local function ensure_adapter()
	if executable(M.adapter.command) then
		return true
	end
	notify(
		('Kotlin DAP adapter not found: %s Install fwcd/kotlin-debug-adapter and put it in PATH.'):format(
			M.adapter.command
		),
		vim.log.levels.ERROR
	)
	return false
end
local function ensure_project_root()
	local root = workspace_root()
	if not has_gradle(root) and not has_maven(root) then
		notify('Kotlin debug requires a Gradle or Maven project root', vim.log.levels.ERROR)
		return nil
	end
	return root
end

local function ensure_built(root)
	if has_compiled_output(root) then
		return true
	end

	local build_now = input('No compiled Kotlin classes found. Build now? [Y/n]: ', 'Y')
	if build_now:lower() == 'n' then
		notify('Build required before Kotlin debug launch', vim.log.levels.WARN)
		return false
	end

	local result
	if has_gradle(root) then
		if executable('gradle') then
			result = vim.system({ 'gradle', 'classes' }, { cwd = root, text = true }):wait()
		elseif executable('./gradlew') then
			result = vim.system({ './gradlew', 'classes' }, { cwd = root, text = true }):wait()
		elseif file_exists(path_join(root, 'gradlew')) then
			result = vim.system({ path_join(root, 'gradlew'), 'classes' }, { cwd = root, text = true }):wait()
		end
	elseif has_maven(root) then
		if executable('mvn') then
			result = vim.system({ 'mvn', '-DskipTests', 'compile' }, { cwd = root, text = true }):wait()
		end
	end

	if not result then
		notify('No supported build command found for Kotlin project', vim.log.levels.ERROR)
		return false
	end

	if result.code ~= 0 then
		local stderr = result.stderr ~= '' and result.stderr or 'Kotlin build failed'
		notify(stderr, vim.log.levels.ERROR)
		return false
	end

	return has_compiled_output(root)
end

local function prompt_args()
	local raw = input('Args: ', '')
	if raw == '' then
		return {}
	end
	return vim.split(raw, '%s+', { trimempty = true })
end

local function prompt_vm_args()
	local raw = input('VM args: ', '')
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

local function package_name_from_file(file)
	if file == '' or not file_exists(file) then
		return nil
	end

	for _, line in ipairs(fn.readfile(file)) do
		local pkg = line:match('^%s*package%s+([%w%._]+)')
		if pkg then
			return pkg
		end
	end

	return nil
end

local function class_name_from_file(file)
	if file == '' then
		return nil
	end
	return fn.fnamemodify(file, ':t:r')
end

local function guessed_main_class()
	local file = current_file()
	if file == '' then
		return nil
	end

	local cls = class_name_from_file(file)
	if not cls then
		return nil
	end

	local pkg = package_name_from_file(file)
	if pkg and pkg ~= '' then
		return pkg .. '.' .. cls
	end

	return cls
end

local function choose_main_class()
	local guess = guessed_main_class() or ''
	local main_class = input('Kotlin main class: ', guess)
	if main_class == '' then
		return nil
	end
	return main_class
end

local function start(config)
	if not ensure_adapter() then
		return
	end

	config.type = M.adapter.name
	debug.start(config)
end

function M.build()
	local root = ensure_project_root()
	if not root then
		return
	end

	if ensure_built(root) then
		notify('Kotlin project build complete')
	end
end

function M.launch_main()
	local root = ensure_project_root()
	if not root then
		return
	end

	if not ensure_built(root) then
		return
	end

	local main_class = choose_main_class()
	if not main_class then
		notify('Main class is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Kotlin launch main',
		projectRoot = root,
		mainClass = main_class,
		args = prompt_args(),
		vmArgs = prompt_vm_args(),
		env = prompt_env(),
		stopOnEntry = false,
	})
end

function M.launch_current_file()
	local root = ensure_project_root()
	if not root then
		return
	end

	if not ensure_built(root) then
		return
	end

	local file = current_file()
	if file == '' or not file_exists(file) then
		notify('Current Kotlin file not found', vim.log.levels.ERROR)
		return
	end

	local main_class = guessed_main_class()
	if not main_class then
		notify('Could not infer main class from current file', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Kotlin launch current file',
		projectRoot = root,
		mainClass = main_class,
		args = prompt_args(),
		vmArgs = prompt_vm_args(),
		env = prompt_env(),
		stopOnEntry = false,
	})
end

function M.launch_prompt()
	local root = ensure_project_root()
	if not root then
		return
	end

	if not ensure_built(root) then
		return
	end

	local main_class = input('Main class: ', '')
	if main_class == '' then
		notify('Main class is required', vim.log.levels.ERROR)
		return
	end

	start({
		request = 'launch',
		name = 'Kotlin launch prompt',
		projectRoot = root,
		mainClass = main_class,
		args = prompt_args(),
		vmArgs = prompt_vm_args(),
		env = prompt_env(),
		stopOnEntry = false,
	})
end

function M.attach_jdwp()
	local host = input('Host: ', '127.0.0.1')
	if host == '' then
		host = '127.0.0.1'
	end

	local port = tonumber(input('Port: ', '5005'))
	if not port then
		notify('Invalid port', vim.log.levels.ERROR)
		return
	end

	debug.start({
		type = 'kotlin-jvm',
		request = 'attach',
		name = 'Kotlin attach JDWP',
		hostName = host,
		port = port,
		cwd = workspace_root(),
	})
end

function M.gradle_debug_hint()
	local root = workspace_root()
	local lines = {
		'Gradle Kotlin/JVM debug examples:',
		'',
		'./gradlew run --debug-jvm',
		'./gradlew test --debug-jvm',
		'',
		'Then attach with host 127.0.0.1 and port 5005 if your JVM is listening there.',
		'',
		'Project root:',
		root,
	}

	vim.cmd('new')
	local buf = api.nvim_get_current_buf()
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].bufhidden = 'wipe'
	vim.bo[buf].filetype = 'markdown'
end

function M.setup()
	api.nvim_create_user_command('KotlinDapBuild', M.build, {
		desc = 'Build Kotlin project classes',
	})

	api.nvim_create_user_command('KotlinDapMain', M.launch_main, {
		desc = 'Debug Kotlin main class',
	})

	api.nvim_create_user_command('KotlinDapFile', M.launch_current_file, {
		desc = 'Debug current Kotlin file as main class',
	})

	api.nvim_create_user_command('KotlinDapPrompt', M.launch_prompt, {
		desc = 'Prompt for Kotlin main class and debug it',
	})

	api.nvim_create_user_command('KotlinDapAttach', M.attach_jdwp, {
		desc = 'Attach to Kotlin/JVM JDWP process',
	})

	api.nvim_create_user_command('KotlinGradleDebugHint', M.gradle_debug_hint, {
		desc = 'Show Gradle debug attach hint',
	})

	vim.keymap.set('n', '<leader>kb', M.build, { desc = 'Kotlin DAP build' })
	vim.keymap.set('n', '<leader>km', M.launch_main, { desc = 'Kotlin DAP main' })
	vim.keymap.set('n', '<leader>kf', M.launch_current_file, { desc = 'Kotlin DAP file' })
	vim.keymap.set('n', '<leader>kp', M.launch_prompt, { desc = 'Kotlin DAP prompt' })
	vim.keymap.set('n', '<leader>ka', M.attach_jdwp, { desc = 'Kotlin DAP attach' })
	vim.keymap.set('n', '<leader>kh', M.gradle_debug_hint, { desc = 'Kotlin gradle debug hint' })
end

return M
