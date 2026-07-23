-- ~/.config/nvim/lua/dap/lldb.lua
-- LLDB DAP configuration for Neovim 0.13 built-in vim.debug, no plugins
--
-- Uses official LLVM lldb-dap.
-- Supports:
-- - Launch executable
-- - Attach by PID
-- - Attach by program path
-- - Core file debugging
-- - Rust/C/C++ friendly defaults

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "lldb-dap",
\tcommand = "lldb-dap",
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.lldb" })
end

local function executable(cmd)
\treturn fn.executable(cmd) == 1
end

local function input(prompt, default, completion)
\treturn fn.input(prompt, default or "", completion or "")
end

local function cwd()
\treturn fn.getcwd()
end

local function current_file()
\treturn api.nvim_buf_get_name(0)
end

local function file_exists(path)
\treturn type(path) == "string" and path ~= "" and uv.fs_stat(path) ~= nil
end

local function is_dir(path)
\tlocal stat = uv.fs_stat(path)
\treturn stat and stat.type == "directory" or false
end

local function path_join(...)
\treturn table.concat({ ... }, "/")
end

local function workspace_root()
\tlocal file = current_file()
\tlocal start = file ~= "" and file or cwd()

\tlocal root = vim.fs.root(start, {
\t\t"Cargo.toml",
\t\t"compile_commands.json",
\t\t"Makefile",
\t\t"CMakeLists.txt",
\t\t".git",
\t})

\treturn root or cwd()
end

local function ensure_adapter()
\tif executable(M.adapter.command) then
\t\treturn M.adapter.command
\tend

\tif fn.has("mac") == 1 and executable("xcrun") then
\t\tlocal result = vim.system({ "xcrun", "-f", "lldb-dap" }, { text = true }):wait()
\t\tif result.code == 0 and result.stdout and result.stdout ~= "" then
\t\t\treturn vim.trim(result.stdout)
\t\tend
\tend

\tnotify(
\t\t"lldb-dap not found in PATH. Install LLVM lldb and ensure lldb-dap is available.",
\t\tvim.log.levels.ERROR
\t)
\treturn nil
end

local function start(config)
\tlocal adapter_cmd = ensure_adapter()
\tif not adapter_cmd then
\t\treturn
\tend

\tconfig.type = M.adapter.name
\tconfig.adapter = {
\t\ttype = "executable",
\t\tcommand = adapter_cmd,
\t\targs = {},
\t}

\tdebug.start(config)
end

local function prompt_args()
\tlocal raw = input("Args: ", "")
\tif raw == "" then
\t\treturn {}
\tend
\treturn vim.split(raw, "%s+", { trimempty = true })
end

local function prompt_env()
\tlocal env = {}
\twhile true do
\t\tlocal key = input("Env key (blank to finish): ", "")
\t\tif key == "" then
\t\t\tbreak
\t\tend
\t\tenv[key] = input("Env value for " .. key .. ": ", "")
\tend
\treturn env
end

local function prompt_program(default)
\tlocal program = input("Program: ", default or (workspace_root() .. "/"), "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

local function cargo_debug_target_guess()
\tlocal root = workspace_root()
\tlocal cargo = path_join(root, "Cargo.toml")
\tif not file_exists(cargo) then
\t\treturn nil
\tend

\tlocal package_name
\tfor _, line in ipairs(fn.readfile(cargo)) do
\t\tlocal name = line:match('^%s*name%s*=%s*"([^"]+)"')
\t\tif name then
\t\t\tpackage_name = name
\t\t\tbreak
\t\tend
\tend

\tif not package_name then
\t\treturn nil
\tend

\tpackage_name = package_name:gsub("%-", "_")
\tlocal target = path_join(root, "target", "debug", package_name)
\tif file_exists(target) then
\t\treturn target
\tend

\treturn target
end

local function c_binary_guess()
\tlocal root = workspace_root()
\tlocal candidates = {
\t\tpath_join(root, "a.out"),
\t\tpath_join(root, "build", "a.out"),
\t\tpath_join(root, "bin", fn.fnamemodify(root, ":t")),
\t\tpath_join(root, "build", fn.fnamemodify(root, ":t")),
\t}

\tfor _, candidate in ipairs(candidates) do
\t\tif file_exists(candidate) then
\t\t\treturn candidate
\t\tend
\tend

\treturn root .. "/"
end

local function default_program_guess()
\tlocal rust_guess = cargo_debug_target_guess()
\tif rust_guess then
\t\treturn rust_guess
\tend
\treturn c_binary_guess()
end

function M.launch()
\tlocal program = prompt_program(default_program_guess())
\tif not program or program == "" then
\t\tnotify("Program is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "LLDB launch",
\t\tprogram = program,
\t\targs = prompt_args(),
\t\tcwd = workspace_root(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t})
end

function M.launch_current_file_binary()
\tlocal file = current_file()
\tif file == "" then
\t\tnotify("No current file", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal stem = fn.fnamemodify(file, ":t:r")
\tlocal root = workspace_root()
\tlocal candidates = {
\t\tpath_join(root, "target", "debug", stem),
\t\tpath_join(root, "build", stem),
\t\tpath_join(root, stem),
\t}

\tlocal picked
\tfor _, candidate in ipairs(candidates) do
\t\tif file_exists(candidate) then
\t\t\tpicked = candidate
\t\t\tbreak
\t\tend
\tend

\tpicked = prompt_program(picked or (root .. "/" .. stem))
\tif not picked or picked == "" then
\t\tnotify("Program is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "LLDB launch current binary",
\t\tprogram = picked,
\t\targs = prompt_args(),
\t\tcwd = workspace_root(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t})
end

function M.attach_pid()
\tlocal pid = tonumber(input("PID: ", ""))
\tif not pid then
\t\tnotify("Invalid PID", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "LLDB attach pid",
\t\tpid = pid,
\t\tcwd = workspace_root(),
\t})
end

function M.attach_program()
\tlocal program = prompt_program(default_program_guess())
\tif not program or program == "" then
\t\tnotify("Program path is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "LLDB attach program",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\twaitFor = true,
\t})
end

function M.open_core()
\tlocal program = prompt_program(default_program_guess())
\tif not program or program == "" then
\t\tnotify("Program path is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal core = input("Core file: ", workspace_root() .. "/", "file")
\tif core == "" then
\t\tnotify("Core file is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "LLDB core file",
\t\tprogram = program,
\t\tcoreFile = core,
\t\tcwd = workspace_root(),
\t})
end

function M.rust_launch()
\tlocal program = prompt_program(cargo_debug_target_guess() or default_program_guess())
\tif not program or program == "" then
\t\tnotify("Rust debug target is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Rust LLDB launch",
\t\tprogram = program,
\t\targs = prompt_args(),
\t\tcwd = workspace_root(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "rust" },
\t})
end

function M.help()
\tlocal lines = {
\t\t"lldb-dap examples",
\t\t"",
\t\t":LldbDapLaunch        - launch an executable",
\t\t":LldbDapAttachPid     - attach to an existing process by PID",
\t\t":LldbDapAttachProgram - wait for and attach to a program path",
\t\t":LldbDapCore          - inspect a core dump",
\t\t":LldbDapRust          - Rust-friendly launch helper",
\t\t"",
\t\t"Install notes:",
\t\t"- Arch Linux: pacman -S lldb",
\t\t"- macOS Homebrew: brew install llvm",
\t\t"- macOS Xcode 16+: xcrun lldb-dap",
\t}

\tvim.cmd("new")
\tlocal buf = api.nvim_get_current_buf()
\tapi.nvim_buf_set_lines(buf, 0, -1, false, lines)
\tvim.bo[buf].bufhidden = "wipe"
\tvim.bo[buf].filetype = "markdown"
end

function M.setup()
\tapi.nvim_create_user_command("LldbDapLaunch", M.launch, {
\t\tdesc = "Launch executable with lldb-dap",
\t})

\tapi.nvim_create_user_command("LldbDapLaunchFile", M.launch_current_file_binary, {
\t\tdesc = "Launch guessed binary for current file",
\t})

\tapi.nvim_create_user_command("LldbDapAttachPid", M.attach_pid, {
\t\tdesc = "Attach to process ID with lldb-dap",
\t})

\tapi.nvim_create_user_command("LldbDapAttachProgram", M.attach_program, {
\t\tdesc = "Attach to program path with lldb-dap",
\t})

\tapi.nvim_create_user_command("LldbDapCore", M.open_core, {
\t\tdesc = "Open core file with lldb-dap",
\t})

\tapi.nvim_create_user_command("LldbDapRust", M.rust_launch, {
\t\tdesc = "Launch Rust target with lldb-dap",
\t})

\tapi.nvim_create_user_command("LldbDapHelp", M.help, {
\t\tdesc = "Show lldb-dap usage help",
\t})

\tvim.keymap.set("n", "<leader>dl", M.launch, { desc = "LLDB DAP launch" })
\tvim.keymap.set("n", "<leader>df", M.launch_current_file_binary, { desc = "LLDB DAP launch file" })
\tvim.keymap.set("n", "<leader>dp", M.attach_pid, { desc = "LLDB DAP attach pid" })
\tvim.keymap.set("n", "<leader>dP", M.attach_program, { desc = "LLDB DAP attach program" })
\tvim.keymap.set("n", "<leader>dc", M.open_core, { desc = "LLDB DAP core file" })
\tvim.keymap.set("n", "<leader>dr", M.rust_launch, { desc = "LLDB DAP rust" })
\tvim.keymap.set("n", "<leader>dh", M.help, { desc = "LLDB DAP help" })
end

return M