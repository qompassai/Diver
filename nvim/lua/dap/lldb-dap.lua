-- ~/.config/nvim/lua/dap/lldb-dap.lua
-- Qompass AI Diver LLDB DAP Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ------------------------------------------------------
local api = vim.api
local fn = vim.fn
local uv = vim.uv
local M = {}
local ADAPTER_NAME = "lldb-dap"
local CONFIGURED_FLAG = "qompass_lldb_dap_configured"
local MAX_EXECUTABLES = 40
local MAX_SCAN_DEPTH = 3
local FILETYPES = {
	c = true,
	cpp = true,
	objc = true,
	objcpp = true,
	rust = true,
}

local FILETYPE_PATTERNS = {
	"c",
	"cpp",
	"objc",
	"objcpp",
	"rust",
}

local FILE_PATTERNS = {
	"*.c",
	"*.h",
	"*.cc",
	"*.cpp",
	"*.cxx",
	"*.hh",
	"*.hpp",
	"*.hxx",
	"*.m",
	"*.mm",
	"*.rs",
}

local SOURCE_SUFFIXES = {
	[".c"] = true,
	[".h"] = true,
	[".cc"] = true,
	[".cpp"] = true,
	[".cxx"] = true,
	[".hh"] = true,
	[".hpp"] = true,
	[".hxx"] = true,
	[".m"] = true,
	[".mm"] = true,
	[".rs"] = true,
}

local ROOT_MARKERS = {
	"Cargo.toml",
	"compile_commands.json",
	"CMakeLists.txt",
	"CMakePresets.json",
	"meson.build",
	"Makefile",
	"makefile",
	"build.ninja",
	".git",
}

local SCAN_DIRECTORIES = {
	"build",
	"bin",
	"out",
	"target/debug",
}

local SKIP_DIRECTORIES = {
	[".git"] = true,
	[".cache"] = true,
	["CMakeFiles"] = true,
	["node_modules"] = true,
}

local NON_EXECUTABLE_SUFFIXES = {
	[".a"] = true,
	[".bc"] = true,
	[".d"] = true,
	[".dll"] = true,
	[".dylib"] = true,
	[".h"] = true,
	[".hh"] = true,
	[".hpp"] = true,
	[".hxx"] = true,
	[".lo"] = true,
	[".o"] = true,
	[".obj"] = true,
	[".pdb"] = true,
	[".rlib"] = true,
	[".so"] = true,
}

---@class LldbAdapterDefinition
---@field name string
---@field command string
---@field args string[]

---@type { lldb: LldbAdapterDefinition }
M.adapters = {
	lldb = {
		name = ADAPTER_NAME,
		command = "lldb-dap",
		args = {},
	},
}

-- Retained for callers which consumed the earlier singular field.
M.adapter = M.adapters.lldb

---@type string?
local cached_adapter_command

---@param message string
---@param level? integer
local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, {
		title = "dap.lldb",
	})
end

---@param command string
---@return boolean
local function executable(command)
	return fn.executable(command) == 1
end

---@param command string
---@return string?
local function executable_path(command)
	local path = fn.exepath(command)
	return path ~= "" and path or nil
end

---@param path string?
---@return boolean
local function file_exists(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "file"
end

---@param path string?
---@return boolean
local function directory_exists(path)
	if type(path) ~= "string" or path == "" then
		return false
	end

	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "directory"
end

---@param prompt string
---@param default? string
---@param completion? string
---@return string
local function input(prompt, default, completion)
	return fn.input(prompt, default or "", completion or "")
end

---@param value string?
---@return string
local function trim(value)
	return type(value) == "string" and vim.trim(value) or ""
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

	return ""
end

---@param path string
---@return string
local function final_suffix(path)
	local name = fn.fnamemodify(path, ":t"):lower()
	return name:match("(%.[^./]+)$") or ""
end

---@param bufnr integer
---@return boolean
local function filename_matches(bufnr)
	return SOURCE_SUFFIXES[suffix(buffer_file(bufnr))] == true
end

---@param bufnr integer
---@return boolean
local function is_lldb_buffer(bufnr)
	if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
		return false
	end

	local name = buffer_file(bufnr)
	if name == "" or vim.bo[bufnr].buftype ~= "" then
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
local function current_lldb_context(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()

	if not is_lldb_buffer(bufnr) then
		notify(
			"LLDB DAP is available only in C, C++, Objective-C, Objective-C++, or Rust source buffers",
			vim.log.levels.ERROR
		)
		return nil, nil, nil
	end

	local file = buffer_file(bufnr)
	return bufnr, project_root(file), file
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
		choices[#choices + 1] = string.format("%d. %s", index, item)
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
		elseif character == "\\" and quote ~= "'" then
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
		elseif character:match("%s") then
			finish()
		else
			current[#current + 1] = character
			token_started = true
		end
	end

	if escaped then
		return nil, "Arguments end with an incomplete escape"
	end
	if quote then
		return nil, "Arguments contain an unterminated quote"
	end

	finish()
	return arguments, nil
end

---@param prompt? string
---@return string[]?
local function prompt_arguments(prompt)
	local arguments, err = parse_arguments(input(prompt or "Program arguments: "))
	if not arguments then
		notify(err or "Unable to parse arguments", vim.log.levels.ERROR)
		return nil
	end

	return arguments
end

---@return table<string, string>?
local function prompt_environment()
	local environment = {}

	while true do
		local name = trim(input("Environment variable (blank to finish): "))
		if name == "" then
			break
		end

		if not name:match("^[%a_][%w_]*$") then
			notify("Invalid environment-variable name: " .. name, vim.log.levels.ERROR)
			return nil
		end

		environment[name] = input(("Value for %s: "):format(name))
	end

	return environment
end

---@param default integer
---@param prompt? string
---@return integer?
local function resolve_port(default, prompt)
	local value = tonumber(input(prompt or "Port: ", tostring(default)))
	if not value or value < 1 or value > 65535 or value % 1 ~= 0 then
		notify("Port must be an integer from 1 through 65535", vim.log.levels.ERROR)
		return nil
	end

	return math.floor(value)
end

---@param path string
---@return boolean
local function native_binary(path)
	local descriptor = uv.fs_open(path, "r", 438)
	if not descriptor then
		return false
	end

	local magic = uv.fs_read(descriptor, 4, 0) or ""
	uv.fs_close(descriptor)

	if magic:sub(1, 4) == "\127ELF" or magic:sub(1, 2) == "MZ" then
		return true
	end

	local signatures = {
		["\xfe\xed\xfa\xce"] = true,
		["\xce\xfa\xed\xfe"] = true,
		["\xfe\xed\xfa\xcf"] = true,
		["\xcf\xfa\xed\xfe"] = true,
		["\xca\xfe\xba\xbe"] = true,
		["\xbe\xba\xfe\xca"] = true,
		["\xca\xfe\xba\xbf"] = true,
		["\xbf\xba\xfe\xca"] = true,
	}

	return signatures[magic] == true
end

---@param path string
---@return boolean
local function is_debuggable_executable(path)
	local name = fn.fnamemodify(path, ":t"):lower()
	if not file_exists(path) or NON_EXECUTABLE_SUFFIXES[final_suffix(path)] or name:match("%.so(%..+)?$") then
		return false
	end

	return executable(path) and native_binary(path)
end

---@param values any
---@param expected string
---@return boolean
local function list_contains_string(values, expected)
	if type(values) ~= "table" then
		return false
	end

	for _, value in ipairs(values) do
		if value == expected then
			return true
		end
	end

	return false
end

---@param root string
---@return string[], string?
local function cargo_target_candidates(root)
	local manifest = vim.fs.joinpath(root, "Cargo.toml")
	if not file_exists(manifest) then
		return {}, nil
	end

	local cargo = executable_path("cargo")
	if cargo then
		local result = vim.system({
			cargo,
			"metadata",
			"--format-version",
			"1",
			"--no-deps",
		}, {
			cwd = root,
			text = true,
		}):wait()

		if result.code == 0 and type(result.stdout) == "string" then
			local ok, metadata = pcall(vim.json.decode, result.stdout)
			if ok and type(metadata) == "table" and type(metadata.target_directory) == "string" then
				local candidates = {}
				local first_guess

				for _, package in ipairs(type(metadata.packages) == "table" and metadata.packages or {}) do
					for _, target in ipairs(type(package.targets) == "table" and package.targets or {}) do
						if type(target.name) == "string" and list_contains_string(target.kind, "bin") then
							local candidate = vim.fs.joinpath(metadata.target_directory, "debug", target.name)
							first_guess = first_guess or candidate
							if is_debuggable_executable(candidate) then
								candidates[#candidates + 1] = candidate
							end
						end
					end
				end

				return candidates, first_guess
			end
		end
	end

	local package_name
	local in_package = false
	for _, line in ipairs(fn.readfile(manifest)) do
		if line:match("^%s*%[") then
			in_package = line:match("^%s*%[package%]%s*$") ~= nil
		elseif in_package then
			package_name = line:match('^%s*name%s*=%s*"([^"]+)"')
			if package_name then
				break
			end
		end
	end

	if not package_name then
		return {}, nil
	end

	local guess = vim.fs.joinpath(root, "target", "debug", package_name)
	return is_debuggable_executable(guess) and { guess } or {}, guess
end

---@param directory string
---@param depth integer
---@param results string[]
---@param seen table<string, boolean>
local function scan_executables(directory, depth, results, seen)
	if depth > MAX_SCAN_DEPTH or #results >= MAX_EXECUTABLES or not directory_exists(directory) then
		return
	end

	local scanner = uv.fs_scandir(directory)
	if not scanner then
		return
	end

	while #results < MAX_EXECUTABLES do
		local name, entry_type = uv.fs_scandir_next(scanner)
		if not name then
			break
		end

		local path = vim.fs.joinpath(directory, name)
		if entry_type == "directory" and not SKIP_DIRECTORIES[name] then
			scan_executables(path, depth + 1, results, seen)
		elseif (entry_type == "file" or entry_type == "link") and not seen[path] and is_debuggable_executable(path) then
			seen[path] = true
			results[#results + 1] = path
		end
	end
end

---@param root string
---@param file string
---@return string[], string?
local function executable_candidates(root, file)
	local results = {}
	local seen = {}
	local cargo_candidates, cargo_guess = cargo_target_candidates(root)

	local function add(path)
		if not seen[path] and is_debuggable_executable(path) then
			seen[path] = true
			results[#results + 1] = path
		end
	end

	for _, candidate in ipairs(cargo_candidates) do
		add(candidate)
	end

	local root_name = fn.fnamemodify(root, ":t")
	local source_stem = fn.fnamemodify(file, ":t:r")
	local conventional = {
		vim.fs.joinpath(root, source_stem),
		vim.fs.joinpath(root, "a.out"),
		vim.fs.joinpath(root, root_name),
		vim.fs.joinpath(root, "build", source_stem),
		vim.fs.joinpath(root, "build", root_name),
		vim.fs.joinpath(root, "build", "a.out"),
		vim.fs.joinpath(root, "build", "bin", source_stem),
		vim.fs.joinpath(root, "build", "bin", root_name),
		vim.fs.joinpath(root, "bin", source_stem),
		vim.fs.joinpath(root, "bin", root_name),
	}

	for _, candidate in ipairs(conventional) do
		add(candidate)
	end

	for _, relative in ipairs(SCAN_DIRECTORIES) do
		scan_executables(vim.fs.joinpath(root, relative), 1, results, seen)
	end

	table.sort(results, function(left, right)
		local function score(path)
			local name = fn.fnamemodify(path, ":t")
			local value = 0

			if name == source_stem then
				value = value + 100
			end
			if name == root_name then
				value = value + 80
			end
			if path:find("/target/debug/", 1, true) then
				value = value + 40
			end
			if path:find("/build/", 1, true) then
				value = value + 20
			end

			return value
		end

		local left_score = score(left)
		local right_score = score(right)
		return left_score == right_score and left < right or left_score > right_score
	end)

	return results, cargo_guess
end

---@param path string
---@param root string
---@return string
local function relative_path(path, root)
	local prefix = root:sub(-1) == "/" and root or root .. "/"
	return path:sub(1, #prefix) == prefix and path:sub(#prefix + 1) or path
end

---@param root string
---@param file string
---@return string?
local function resolve_program(root, file)
	local candidates, cargo_guess = executable_candidates(root, file)
	if #candidates > 0 then
		local labels = {}
		local paths = {}

		for _, candidate in ipairs(candidates) do
			local label = relative_path(candidate, root)
			labels[#labels + 1] = label
			paths[label] = candidate
		end

		local selected = pick(labels, "LLDB executable:")
		if selected then
			return paths[selected]
		end

		return nil
	end

	local default = cargo_guess or (root .. "/")
	local selected = input("LLDB executable: ", default, "file")
	if not is_debuggable_executable(selected) then
		notify("Select an existing executable file", vim.log.levels.ERROR)
		return nil
	end

	return selected
end

---@return string?
local function xcrun_lldb_dap()
	if fn.has("mac") ~= 1 or not executable("xcrun") then
		return nil
	end

	local result = vim.system({
		"xcrun",
		"-f",
		"lldb-dap",
	}, {
		text = true,
	}):wait()

	if result.code ~= 0 then
		return nil
	end

	local path = trim(result.stdout)
	return executable(path) and path or nil
end

---@return string[]
local function adapter_candidates()
	local configured = vim.g.qompass_lldb_dap_path
	local environment = vim.env.NVIM_LLDB_DAP

	return {
		type(configured) == "string" and configured or "",
		type(environment) == "string" and environment or "",
		executable_path("lldb-dap") or "",
		"/usr/bin/lldb-dap",
		"/opt/homebrew/opt/llvm/bin/lldb-dap",
		"/usr/local/opt/llvm/bin/lldb-dap",
	}
end

---@class LldbDapAdapter
---@field name string
---@field type string
---@field command string
---@field args string[]

---@return LldbDapAdapter?
function M.resolve_adapter()
	if cached_adapter_command and executable(cached_adapter_command) then
		return {
			name = ADAPTER_NAME,
			type = "executable",
			command = cached_adapter_command,
			args = {},
		}
	end

	for _, candidate in ipairs(adapter_candidates()) do
		if candidate ~= "" and executable(candidate) then
			cached_adapter_command = executable_path(candidate) or candidate
			break
		end
	end

	cached_adapter_command = cached_adapter_command or xcrun_lldb_dap()
	if not cached_adapter_command then
		notify(
			"lldb-dap was not found. On Arch Linux install the lldb package; otherwise set NVIM_LLDB_DAP or vim.g.qompass_lldb_dap_path",
			vim.log.levels.ERROR
		)
		return nil
	end

	M.adapters.lldb.command = cached_adapter_command

	return {
		name = ADAPTER_NAME,
		type = "executable",
		command = cached_adapter_command,
		args = {},
	}
end

---@param silent? boolean
---@return table?
local function debug_client(silent)
	local client = rawget(vim, "debug")

	if type(client) ~= "table" or type(client.start) ~= "function" then
		if not silent then
			notify(
				"vim.debug is unavailable. Neovim 0.13 does not include a native DAP client; load the same DAP core used by the other dap modules",
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

	configuration.type = ADAPTER_NAME
	configuration.adapter = {
		type = adapter.type,
		command = adapter.command,
		args = adapter.args,
	}

	-- The second argument is ignored by one-argument clients and allows a
	-- plugin-free custom DAP core to consume the resolved adapter directly.
	local ok, err = pcall(client.start, configuration, adapter)
	if not ok then
		notify("Unable to start LLDB DAP: " .. tostring(err), vim.log.levels.ERROR)
	end
end

---@param root string
---@return table
local function common_configuration(root)
	return {
		debuggerRoot = root,
		commandEscapePrefix = "`",
		displayExtendedBacktrace = true,
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

function M.launch()
	local _, root, file = current_lldb_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	local program = resolve_program(root, file)
	if not program then
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
		request = "launch",
		name = "LLDB: launch executable",
		program = program,
		args = arguments,
		cwd = root,
		env = environment,
		stopOnEntry = false,
		console = "internalConsole",
	}))
end

function M.launch_stop_on_entry()
	local _, root, file = current_lldb_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	local program = resolve_program(root, file)
	if not program then
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
		request = "launch",
		name = "LLDB: launch and stop on entry",
		program = program,
		args = arguments,
		cwd = root,
		env = environment,
		stopOnEntry = true,
		console = "internalConsole",
	}))
end

---@return { pid: integer, label: string }[]
local function processes()
	if not executable("ps") then
		return {}
	end

	local command = {
		"ps",
		"-u",
		tostring(uv.os_getuid()),
		"-o",
		"pid=,comm=",
	}
	local result = vim.system(command, {
		text = true,
	}):wait()

	if result.code ~= 0 or type(result.stdout) ~= "string" then
		return {}
	end

	local current_pid = uv.os_getpid()
	local entries = {}
	for line in result.stdout:gmatch("[^\r\n]+") do
		local pid_text, command_name = line:match("^%s*(%d+)%s+(.+)%s*$")
		local pid = tonumber(pid_text)
		if pid and pid > 0 and pid ~= current_pid and command_name then
			entries[#entries + 1] = {
				pid = math.floor(pid),
				label = ("%d  %s"):format(pid, command_name),
			}
		end
	end

	table.sort(entries, function(left, right)
		return left.pid < right.pid
	end)

	return entries
end

---@param pid integer
---@param root string
local function attach_pid(pid, root)
	start(extend(common_configuration(root), {
		request = "attach",
		name = ("LLDB: attach PID %d"):format(pid),
		pid = pid,
	}))
end

function M.attach_process()
	local _, root = current_lldb_context(api.nvim_get_current_buf())
	if not root then
		return
	end

	local entries = processes()
	if #entries == 0 then
		notify("No processes could be enumerated; use :LldbDapAttachPid", vim.log.levels.WARN)
		return
	end

	local labels = {}
	local by_label = {}
	for _, entry in ipairs(entries) do
		labels[#labels + 1] = entry.label
		by_label[entry.label] = entry.pid
	end

	local selected = pick(labels, "Process:")
	local pid = selected and by_label[selected] or nil
	if pid then
		attach_pid(pid, root)
	end
end

function M.attach_pid()
	local _, root = current_lldb_context(api.nvim_get_current_buf())
	if not root then
		return
	end

	local value = tonumber(input("Process ID: "))
	if not value or value < 1 or value % 1 ~= 0 then
		notify("Process ID must be a positive integer", vim.log.levels.ERROR)
		return
	end

	attach_pid(math.floor(value), root)
end

function M.attach_program()
	local _, root, file = current_lldb_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	local program = resolve_program(root, file)
	if not program then
		return
	end

	start(extend(common_configuration(root), {
		request = "attach",
		name = "LLDB: attach by executable name",
		program = program,
	}))
end

function M.wait_for_program()
	local _, root, file = current_lldb_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	if fn.has("mac") ~= 1 then
		notify("lldb-dap waitFor attach is currently supported only on macOS", vim.log.levels.ERROR)
		return
	end

	local program = resolve_program(root, file)
	if not program then
		return
	end

	start(extend(common_configuration(root), {
		request = "attach",
		name = "LLDB: wait for executable",
		program = program,
		waitFor = true,
	}))
end

function M.open_core()
	local _, root, file = current_lldb_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	local program = resolve_program(root, file)
	if not program then
		return
	end

	local core = input("Core file: ", root .. "/", "file")
	if not file_exists(core) then
		notify("Select an existing core file", vim.log.levels.ERROR)
		return
	end

	start(extend(common_configuration(root), {
		request = "attach",
		name = "LLDB: inspect core file",
		program = program,
		coreFile = core,
	}))
end

---@param host string
---@return boolean
local function valid_host(host)
	return host ~= "" and host:match("^[%w%.:_%-]+$") ~= nil
end

function M.attach_remote()
	local _, root, file = current_lldb_context(api.nvim_get_current_buf())
	if not root or not file then
		return
	end

	local program = resolve_program(root, file)
	if not program then
		return
	end

	local host = trim(input("Remote host: ", "127.0.0.1"))
	if not valid_host(host) then
		notify("Remote host contains invalid characters", vim.log.levels.ERROR)
		return
	end

	local port = resolve_port(2345, "Remote gdb-server port: ")
	if not port then
		return
	end

	start(extend(common_configuration(root), {
		request = "attach",
		name = ("LLDB: remote %s:%d"):format(host, port),
		program = program,
		["gdb-remote-host"] = host,
		["gdb-remote-port"] = port,
	}))
end

-- Backward-compatible helpers from the earlier module. Generic launch now
-- performs current-file and Cargo-aware executable discovery.
M.launch_current_file_binary = M.launch
M.rust_launch = M.launch

function M.help()
	local lines = {
		"# lldb-dap commands",
		"",
		"- `:LldbDapLaunch` — launch an executable.",
		"- `:LldbDapLaunchStop` — launch and stop on entry.",
		"- `:LldbDapAttach` — select one of the current user processes.",
		"- `:LldbDapAttachPid` — attach using a numeric process ID.",
		"- `:LldbDapAttachProgram` — attach to a running executable by name.",
		"- `:LldbDapWaitProgram` — wait for a program on macOS.",
		"- `:LldbDapCore` — inspect a core dump.",
		"- `:LldbDapRemote` — attach to lldb-server or gdbserver.",
		"",
		"## Installation",
		"",
		"- Arch Linux: `pacman -S lldb`",
		"- macOS with Xcode: `xcrun -f lldb-dap`",
		"- Override: `NVIM_LLDB_DAP=/absolute/path/to/lldb-dap`",
		'- Lua override: `vim.g.qompass_lldb_dap_path = "/absolute/path/to/lldb-dap"`',
	}

	vim.cmd("botright new")
	local bufnr = api.nvim_get_current_buf()
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].swapfile = false
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].modifiable = false
end

---@param bufnr integer
local function configure_buffer(bufnr)
	if not is_lldb_buffer(bufnr) or vim.b[bufnr][CONFIGURED_FLAG] then
		return
	end

	vim.b[bufnr][CONFIGURED_FLAG] = true

	api.nvim_buf_create_user_command(bufnr, "LldbDapLaunch", M.launch, {
		desc = "Launch an executable with lldb-dap",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapLaunchFile", M.launch_current_file_binary, {
		desc = "Launch a current-file-aware executable with lldb-dap",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapLaunchStop", M.launch_stop_on_entry, {
		desc = "Launch an executable and stop on entry",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapAttach", M.attach_process, {
		desc = "Select and attach to a process with lldb-dap",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapAttachPid", M.attach_pid, {
		desc = "Attach to a process ID with lldb-dap",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapAttachProgram", M.attach_program, {
		desc = "Attach to a running executable by name",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapWaitProgram", M.wait_for_program, {
		desc = "Wait for and attach to an executable on macOS",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapCore", M.open_core, {
		desc = "Inspect a core file with lldb-dap",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapRemote", M.attach_remote, {
		desc = "Attach to lldb-server or gdbserver",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapRust", M.rust_launch, {
		desc = "Launch a Cargo-aware Rust executable with lldb-dap",
	})
	api.nvim_buf_create_user_command(bufnr, "LldbDapHelp", M.help, {
		desc = "Show lldb-dap usage help",
	})

	local function map(lhs, rhs, description)
		vim.keymap.set("n", lhs, rhs, {
			buffer = bufnr,
			desc = description,
			silent = true,
		})
	end

	map("<leader>dll", M.launch, "LLDB launch")
	map("<leader>dle", M.launch_stop_on_entry, "LLDB launch stop on entry")
	map("<leader>dla", M.attach_process, "LLDB select process")
	map("<leader>dlp", M.attach_pid, "LLDB attach PID")
	map("<leader>dln", M.attach_program, "LLDB attach by name")
	map("<leader>dlw", M.wait_for_program, "LLDB wait for program")
	map("<leader>dlc", M.open_core, "LLDB inspect core")
	map("<leader>dlr", M.attach_remote, "LLDB remote attach")
	map("<leader>dlh", M.help, "LLDB help")
end

function M.setup()
	local group = api.nvim_create_augroup("qompass.dap.lldb", {
		clear = true,
	})

	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = FILETYPE_PATTERNS,
		desc = "Enable LLDB DAP for native-language buffers",
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = group,
		pattern = FILE_PATTERNS,
		desc = "Enable LLDB DAP for native source files",
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	configure_buffer(api.nvim_get_current_buf())
end

return M
