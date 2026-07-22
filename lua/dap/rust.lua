-- ~/.config/nvim/lua/dap/rust.lua
-- Rust DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "codelldb",
\tcommand = "codelldb",
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.rust" })
end

local function executable(cmd)
\treturn fn.executable(cmd) == 1
end

local function cwd()
\treturn fn.getcwd()
end

local function input(prompt, default, completion)
\treturn fn.input(prompt, default or "", completion or "")
end

local function file_exists(path)
\treturn type(path) == "string" and path ~= "" and uv.fs_stat(path) ~= nil
end

local function is_executable(path)
\treturn file_exists(path) and fn.executable(path) == 1
end

local function current_file()
\treturn api.nvim_buf_get_name(0)
end

local function workspace_root()
\tlocal file = current_file()
\tif file == "" then
\t\treturn cwd()
\tend

\tlocal root = vim.fs.root(file, {
\t\t"Cargo.toml",
\t\t"rust-project.json",
\t\t".git",
\t})

\treturn root or cwd()
end

local function cargo_toml_path()
\treturn workspace_root() .. "/Cargo.toml"
end

local function cargo_package_name()
\tlocal path = cargo_toml_path()
\tif not file_exists(path) then
\t\treturn nil
\tend

\tfor _, line in ipairs(fn.readfile(path)) do
\t\tlocal name = line:match('^%s*name%s*=%s*"([^"]+)"')
\t\tif name then
\t\t\treturn name
\t\tend
\tend

\treturn nil
end

local function cargo_metadata_target_dir()
\tlocal root = workspace_root()
\tif not executable("cargo") then
\t\treturn root .. "/target"
\tend

\tlocal result = vim.system({
\t\t"cargo",
\t\t"metadata",
\t\t"--format-version",
\t\t"1",
\t\t"--no-deps",
\t}, {
\t\tcwd = root,
\t\ttext = true,
\t}):wait()

\tif result.code ~= 0 or not result.stdout or result.stdout == "" then
\t\treturn root .. "/target"
\tend

\tlocal ok, decoded = pcall(vim.json.decode, result.stdout)
\tif not ok or type(decoded) ~= "table" then
\t\treturn root .. "/target"
\tend

\treturn decoded.target_directory or (root .. "/target")
end

local function target_debug_dir()
\treturn cargo_metadata_target_dir() .. "/debug"
end

local function ensure_adapter()
\tif executable(M.adapter.command) then
\t\treturn true
\tend

\tnotify(
\t\t("Rust DAP adapter not found: %s
Install codelldb and ensure it is available in PATH.")
\t\t\t:format(M.adapter.command),
\t\tvim.log.levels.ERROR
\t)
\treturn false
end

local function start(config)
\tif not ensure_adapter() then
\t\treturn
\tend

\tconfig.type = M.adapter.name
\tdebug.start(config)
end

local function cargo_build(args)
\tlocal root = workspace_root()

\tif not executable("cargo") then
\t\tnotify("cargo not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\tlocal cmd = { "cargo" }
\tvim.list_extend(cmd, args)

\tnotify("Running: " .. table.concat(cmd, " "))

\tlocal result = vim.system(cmd, {
\t\tcwd = root,
\t\ttext = true,
\t}):wait()

\tif result.code ~= 0 then
\t\tlocal stderr = (result.stderr and result.stderr ~= "") and result.stderr or "cargo command failed"
\t\tnotify(stderr, vim.log.levels.ERROR)
\t\treturn false
\tend

\treturn true
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

local function candidate_bins()
\tlocal dir = target_debug_dir()
\tif not file_exists(dir) then
\t\treturn {}
\tend

\tlocal scanner = uv.fs_scandir(dir)
\tif not scanner then
\t\treturn {}
\tend

\tlocal items = {}
\twhile true do
\t\tlocal name, typ = uv.fs_scandir_next(scanner)
\t\tif not name then
\t\t\tbreak
\t\tend

\t\tlocal path = dir .. "/" .. name
\t\tif typ == "file"
\t\t\tand is_executable(path)
\t\t\tand not name:match("%.d$")
\t\t\tand not name:match("%.rlib$")
\t\t\tand not name:match("%.rmeta$")
\t\t\tand not name:match("%.[oa]$")
\t\t\tand not name:match("^build%-script")
\t\tthen
\t\t\titems[#items + 1] = path
\t\tend
\tend

\ttable.sort(items)
\treturn items
end

local function choose(items, prompt)
\tif #items == 0 then
\t\treturn nil
\tend

\tlocal choices = { prompt or "Select:" }
\tfor i, item in ipairs(items) do
\t\tchoices[#choices + 1] = string.format("%d. %s", i, fn.fnamemodify(item, ":t"))
\tend

\tlocal idx = fn.inputlist(choices)
\tif idx < 1 or idx > #items then
\t\treturn nil
\tend

\treturn items[idx]
end

local function resolve_program()
\tlocal bins = candidate_bins()
\tif #bins == 1 then
\t\treturn bins[1]
\tend
\tif #bins > 1 then
\t\tlocal picked = choose(bins, "Rust executable:")
\t\tif picked then
\t\t\treturn picked
\t\tend
\tend

\tlocal pkg = cargo_package_name()
\tlocal default = target_debug_dir() .. "/"
\tif pkg then
\t\tdefault = target_debug_dir() .. "/" .. pkg
\tend

\tlocal program = input("Path to executable: ", default, "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

function M.build()
\tcargo_build({ "build" })
end

function M.build_release()
\tcargo_build({ "build", "--release" })
end

function M.run_binary()
\tif not cargo_build({ "build" }) then
\t\treturn
\tend

\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Rust executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Rust launch binary",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "rust" },
\t})
end

function M.run_current_package()
\tlocal pkg = cargo_package_name()
\tif not pkg then
\t\tnotify("Could not resolve package name from Cargo.toml", vim.log.levels.ERROR)
\t\treturn
\tend

\tif not cargo_build({ "build", "--package", pkg }) then
\t\treturn
\tend

\tlocal program = target_debug_dir() .. "/" .. pkg
\tif vim.loop.os_uname().sysname == "Windows_NT" then
\t\tprogram = program .. ".exe"
\tend

\tif not file_exists(program) then
\t\tprogram = resolve_program()
\tend

\tif not program or not file_exists(program) then
\t\tnotify("Rust package executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Rust launch package",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "rust" },
\t})
end

function M.debug_test()
\tlocal root = workspace_root()
\tlocal target_name = input("Test target (blank for current package): ", cargo_package_name() or "")
\tlocal build_args = { "test", "--no-run" }

\tif target_name ~= "" then
\t\tvim.list_extend(build_args, { "--package", target_name })
\tend

\tif not cargo_build(build_args) then
\t\treturn
\tend

\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Compiled test executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal test_filter = input("Test filter: ", "")
\tlocal args = {}
\tif test_filter ~= "" then
\t\targs[#args + 1] = test_filter
\tend
\tvim.list_extend(args, prompt_args())

\tstart({
\t\trequest = "launch",
\t\tname = "Rust debug test",
\t\tprogram = program,
\t\tcwd = root,
\t\targs = args,
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "rust" },
\t})
end

function M.attach_pid()
\tlocal pid = tonumber(input("PID: ", ""))
\tif not pid then
\t\tnotify("Invalid PID", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal program = input("Path to executable (optional): ", target_debug_dir() .. "/", "file")
\tif program == "" then
\t\tprogram = nil
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Rust attach PID",
\t\tpid = pid,
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\tsourceLanguages = { "rust" },
\t})
end

function M.attach_executable()
\tlocal program = input("Path to executable: ", target_debug_dir() .. "/", "file")
\tif program == "" or not file_exists(program) then
\t\tnotify("Executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Rust attach executable",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\tsourceLanguages = { "rust" },
\t})
end

function M.setup()
\tapi.nvim_create_user_command("RustDapBuild", M.build, {
\t\tdesc = "cargo build",
\t})

\tapi.nvim_create_user_command("RustDapBuildRelease", M.build_release, {
\t\tdesc = "cargo build --release",
\t})

\tapi.nvim_create_user_command("RustDapRun", M.run_binary, {
\t\tdesc = "Build and debug Rust binary",
\t})

\tapi.nvim_create_user_command("RustDapPackage", M.run_current_package, {
\t\tdesc = "Build and debug current Rust package",
\t})

\tapi.nvim_create_user_command("RustDapTest", M.debug_test, {
\t\tdesc = "Build tests and debug Rust test binary",
\t})

\tapi.nvim_create_user_command("RustDapAttachPid", M.attach_pid, {
\t\tdesc = "Attach debugger to running Rust PID",
\t})

\tapi.nvim_create_user_command("RustDapAttachExe", M.attach_executable, {
\t\tdesc = "Attach debugger to Rust executable",
\t})

\tvim.keymap.set("n", "<leader>rb", M.build, { desc = "Rust DAP build" })
\tvim.keymap.set("n", "<leader>rB", M.build_release, { desc = "Rust DAP build release" })
\tvim.keymap.set("n", "<leader>rd", M.run_binary, { desc = "Rust DAP run" })
\tvim.keymap.set("n", "<leader>rp", M.run_current_package, { desc = "Rust DAP package" })
\tvim.keymap.set("n", "<leader>rt", M.debug_test, { desc = "Rust DAP test" })
\tvim.keymap.set("n", "<leader>ra", M.attach_pid, { desc = "Rust DAP attach pid" })
\tvim.keymap.set("n", "<leader>re", M.attach_executable, { desc = "Rust DAP attach exe" })
end

return M