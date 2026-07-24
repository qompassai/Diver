-- ~/.config/nvim/lua/dap/go.lua
-- Go DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "delve",
\tcommand = "dlv",
\targs = { "dap", "--listen=127.0.0.1:0" },
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.go" })
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

local function goos_windows()
\treturn vim.uv.os_uname().sysname == "Windows_NT"
end

local function normalize_sep(path)
\tif goos_windows() then
\t\treturn (path:gsub("/", "\\"))
\tend
\treturn path
end

local function joinpath(...)
\treturn normalize_sep(table.concat({ ... }, "/"))
end

local function workspace_root()
\tlocal file = current_file()
\tif file == "" then
\t\treturn cwd()
\tend

\tlocal root = vim.fs.root(file, {
\t\t"go.work",
\t\t"go.mod",
\t\t".git",
\t})

\treturn root or cwd()
end

local function current_dir()
\tlocal file = current_file()
\tif file == "" then
\t\treturn cwd()
\tend
\treturn fn.fnamemodify(file, ":p:h")
end

local function buf_name()
\tlocal file = current_file()
\tif file == "" then
\t\treturn ""
\tend
\treturn fn.fnamemodify(file, ":t")
end

local function buf_stem()
\tlocal name = buf_name()
\treturn name:gsub("%.go$", "")
end

local function ensure_adapter()
\tif executable(M.adapter.command) then
\t\treturn true
\tend

\tnotify(
\t\t("Go DAP adapter not found: %s
Install Delve and ensure it is available in PATH.")
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

local function go_env(args, run_cwd)
\tlocal cmd = { "go" }
\tvim.list_extend(cmd, args)

\tlocal result = vim.system(cmd, {
\t\tcwd = run_cwd or workspace_root(),
\t\ttext = true,
\t}):wait()

\tif result.code ~= 0 or not result.stdout or result.stdout == "" then
\t\treturn nil
\tend

\treturn vim.trim(result.stdout)
end

local function go_env_gomod(run_cwd)
\tif not executable("go") then
\t\treturn nil
\tend
\treturn go_env({ "env", "GOMOD" }, run_cwd)
end

local function go_env_gowork(run_cwd)
\tif not executable("go") then
\t\treturn nil
\tend
\treturn go_env({ "env", "GOWORK" }, run_cwd)
end

local function module_root()
\tlocal gomod = go_env_gomod(workspace_root())
\tif gomod and gomod ~= "" and gomod ~= "/dev/null" and gomod ~= "NUL" then
\t\treturn fn.fnamemodify(gomod, ":p:h")
\tend
\treturn workspace_root()
end

local function work_root()
\tlocal gowork = go_env_gowork(workspace_root())
\tif gowork and gowork ~= "" and gowork ~= "/dev/null" and gowork ~= "NUL" then
\t\treturn fn.fnamemodify(gowork, ":p:h")
\tend
\treturn workspace_root()
end

local function package_dir_for_file()
\tlocal file = current_file()
\tif file == "" then
\t\treturn workspace_root()
\tend
\treturn fn.fnamemodify(file, ":p:h")
end

local function test_binary_name(dir)
\tlocal base = fn.fnamemodify(dir, ":t")
\tif base == "" then
\t\tbase = "go-test"
\tend
\tlocal name = base .. ".test"
\tif goos_windows() then
\t\tname = name .. ".exe"
\tend
\treturn name
end

local function build_output_dir()
\treturn joinpath(workspace_root(), ".nvim", "debug")
end

local function ensure_dir(path)
\tfn.mkdir(path, "p")
\treturn path
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

local function scandir_execs(dir)
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

\t\tlocal path = joinpath(dir, name)
\t\tif typ == "file" and is_executable(path) then
\t\t\titems[#items + 1] = path
\t\tend
\tend

\ttable.sort(items)
\treturn items
end

local function candidate_binaries()
\treturn scandir_execs(build_output_dir())
end

local function resolve_executable(default)
\tlocal bins = candidate_binaries()
\tif #bins == 1 then
\t\treturn bins[1]
\tend
\tif #bins > 1 then
\t\tlocal picked = choose(bins, "Go executable:")
\t\tif picked then
\t\t\treturn picked
\t\tend
\tend

\tlocal program = input("Path to executable: ", default or (build_output_dir() .. "/"), "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

local function go_build(args, run_cwd)
\tlocal root = run_cwd or workspace_root()

\tif not executable("go") then
\t\tnotify("go not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\tlocal cmd = { "go" }
\tvim.list_extend(cmd, args)

\tnotify("Running: " .. table.concat(cmd, " "))

\tlocal result = vim.system(cmd, {
\t\tcwd = root,
\t\ttext = true,
\t}):wait()

\tif result.code ~= 0 then
\t\tlocal stderr = (result.stderr and result.stderr ~= "") and result.stderr or "go command failed"
\t\tnotify(stderr, vim.log.levels.ERROR)
\t\treturn false
\tend

\treturn true
end

local function current_main_file()
\tlocal file = current_file()
\tif file == "" or not file:match("%.go$") then
\t\treturn nil
\tend

\tlocal lines = api.nvim_buf_get_lines(0, 0, math.min(api.nvim_buf_line_count(0), 50), false)
\tlocal pkg_main = false
\tlocal has_main = false

\tfor _, line in ipairs(lines) do
\t\tif line:match("^%s*package%s+main%s*$") then
\t\t\tpkg_main = true
\t\tend
\t\tif line:match("^%s*func%s+main%s*%(") then
\t\t\thas_main = true
\t\tend
\tend

\tif pkg_main and has_main then
\t\treturn file
\tend

\treturn nil
end

local function default_launch_program()
\tlocal main_file = current_main_file()
\tif main_file then
\t\treturn main_file
\tend
\treturn package_dir_for_file()
end

local function launch_config(name, mode, program, extra)
\tlocal config = {
\t\trequest = "launch",
\t\tname = name,
\t\tmode = mode,
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t}
\tif extra then
\t\tconfig = vim.tbl_extend("force", config, extra)
\tend
\treturn config
end

function M.run_package()
\tstart(launch_config(
\t\t"Go launch package",
\t\t"debug",
\t\tdefault_launch_program()
\t))
end

function M.run_module_root()
\tstart(launch_config(
\t\t"Go launch module",
\t\t"debug",
\t\tmodule_root()
\t))
end

function M.run_workspace_root()
\tstart(launch_config(
\t\t"Go launch workspace",
\t\t"debug",
\t\twork_root()
\t))
end

function M.debug_test_file()
\tlocal file = current_file()
\tif file == "" or not file:match("_test%.go$") then
\t\tnotify("Current buffer is not a Go test file", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart(launch_config(
\t\t"Go debug test file",
\t\t"test",
\t\tfile
\t))
end

function M.debug_test_package()
\tlocal dir = package_dir_for_file()
\tstart(launch_config(
\t\t"Go debug test package",
\t\t"test",
\t\tdir
\t))
end

function M.build_binary()
\tlocal outdir = ensure_dir(build_output_dir())
\tlocal default = joinpath(outdir, buf_stem() ~= "" and buf_stem() or fn.fnamemodify(package_dir_for_file(), ":t"))
\tif goos_windows() then
\t\tdefault = default .. ".exe"
\tend

\tlocal output = input("Build output: ", default, "file")
\tif output == "" then
\t\treturn
\tend

\tgo_build({ "build", "-gcflags=all=-N -l", "-o", output, default_launch_program() }, workspace_root())
end

function M.build_test_binary()
\tlocal outdir = ensure_dir(build_output_dir())
\tlocal pkg = package_dir_for_file()
\tlocal default = joinpath(outdir, test_binary_name(pkg))

\tlocal output = input("Test binary output: ", default, "file")
\tif output == "" then
\t\treturn
\tend

\tgo_build({ "test", "-c", "-gcflags=all=-N -l", "-o", output, pkg }, workspace_root())
end

function M.run_executable()
\tlocal default = build_output_dir() .. "/"
\tlocal program = resolve_executable(default)
\tif not program or not file_exists(program) then
\t\tnotify("Go executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Go launch executable",
\t\tmode = "exec",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t})
end

function M.debug_test_binary()
\tlocal outdir = ensure_dir(build_output_dir())
\tlocal pkg = package_dir_for_file()
\tlocal default = joinpath(outdir, test_binary_name(pkg))

\tif not go_build({ "test", "-c", "-gcflags=all=-N -l", "-o", default, pkg }, workspace_root()) then
\t\treturn
\tend

\tif not file_exists(default) then
\t\tnotify("Compiled test executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal test_filter = input("Test filter (-test.run): ", "")
\tlocal args = {}
\tif test_filter ~= "" then
\t\tvim.list_extend(args, { "-test.run", test_filter })
\tend
\tvim.list_extend(args, prompt_args())

\tstart({
\t\trequest = "launch",
\t\tname = "Go debug test binary",
\t\tmode = "exec",
\t\tprogram = default,
\t\tcwd = workspace_root(),
\t\targs = args,
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
\t\tname = "Go attach PID",
\t\tmode = "local",
\t\tprocessId = pid,
\t\tcwd = workspace_root(),
\t\tstopOnEntry = false,
\t})
end

function M.attach_executable()
\tlocal default = build_output_dir() .. "/"
\tlocal program = input("Path to executable: ", default, "file")
\tif program == "" or not file_exists(program) then
\t\tnotify("Executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal pid = tonumber(input("PID: ", ""))
\tif not pid then
\t\tnotify("Invalid PID", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Go attach executable",
\t\tmode = "local",
\t\tprocessId = pid,
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\tstopOnEntry = false,
\t})
end

function M.setup()
\tapi.nvim_create_user_command("GoDapBuild", M.build_binary, {
\t\tdesc = "go build -gcflags=all=-N -l",
\t})

\tapi.nvim_create_user_command("GoDapBuildTest", M.build_test_binary, {
\t\tdesc = "go test -c -gcflags=all=-N -l",
\t})

\tapi.nvim_create_user_command("GoDapRun", M.run_package, {
\t\tdesc = "Debug Go package or current main file",
\t})

\tapi.nvim_create_user_command("GoDapModule", M.run_module_root, {
\t\tdesc = "Debug Go module root",
\t})

\tapi.nvim_create_user_command("GoDapWorkspace", M.run_workspace_root, {
\t\tdesc = "Debug Go workspace root",
\t})

\tapi.nvim_create_user_command("GoDapExec", M.run_executable, {
\t\tdesc = "Debug prebuilt Go executable",
\t})

\tapi.nvim_create_user_command("GoDapTestFile", M.debug_test_file, {
\t\tdesc = "Debug current Go test file",
\t})

\tapi.nvim_create_user_command("GoDapTest", M.debug_test_package, {
\t\tdesc = "Debug Go tests in current package",
\t})

\tapi.nvim_create_user_command("GoDapTestBinary", M.debug_test_binary, {
\t\tdesc = "Build test binary and debug it",
\t})

\tapi.nvim_create_user_command("GoDapAttachPid", M.attach_pid, {
\t\tdesc = "Attach debugger to running Go PID",
\t})

\tapi.nvim_create_user_command("GoDapAttachExe", M.attach_executable, {
\t\tdesc = "Attach debugger to Go executable with PID",
\t})

\tvim.keymap.set("n", "<leader>gb", M.build_binary, { desc = "Go DAP build" })
\tvim.keymap.set("n", "<leader>gB", M.build_test_binary, { desc = "Go DAP build test" })
\tvim.keymap.set("n", "<leader>gd", M.run_package, { desc = "Go DAP run" })
\tvim.keymap.set("n", "<leader>gm", M.run_module_root, { desc = "Go DAP module" })
\tvim.keymap.set("n", "<leader>gw", M.run_workspace_root, { desc = "Go DAP workspace" })
\tvim.keymap.set("n", "<leader>ge", M.run_executable, { desc = "Go DAP exec" })
\tvim.keymap.set("n", "<leader>gt", M.debug_test_package, { desc = "Go DAP test package" })
\tvim.keymap.set("n", "<leader>gT", M.debug_test_file, { desc = "Go DAP test file" })
\tvim.keymap.set("n", "<leader>gA", M.debug_test_binary, { desc = "Go DAP test binary" })
\tvim.keymap.set("n", "<leader>ga", M.attach_pid, { desc = "Go DAP attach pid" })
\tvim.keymap.set("n", "<leader>gE", M.attach_executable, { desc = "Go DAP attach exe" })
end

return M