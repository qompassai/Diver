-- ~/.config/nvim/lua/dap/zig.lua
-- Zig DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapters = {
\tprimary = {
\t\tname = "lldb-dap",
\t\tcommand = "lldb-dap",
\t},
\tfallback = {
\t\tname = "codelldb",
\t\tcommand = "codelldb",
\t},
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.zig" })
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
\t\t"build.zig",
\t\t"build.zig.zon",
\t\t".git",
\t})

\treturn root or cwd()
end

local function project_name()
\treturn fn.fnamemodify(workspace_root(), ":t")
end

local function zig_out_bin()
\treturn path_join(workspace_root(), "zig-out", "bin")
end

local function zig_cache_bin()
\treturn path_join(workspace_root(), "zig-cache", "bin")
end

local function resolve_adapter()
\tif executable(M.adapters.primary.command) then
\t\treturn M.adapters.primary
\tend
\tif executable(M.adapters.fallback.command) then
\t\treturn M.adapters.fallback
\tend

\tnotify(
\t\t("No Zig-capable LLDB DAP adapter found. Install %s or %s.")
\t\t\t:format(M.adapters.primary.command, M.adapters.fallback.command),
\t\tvim.log.levels.ERROR
\t)
\treturn nil
end

local function start(config)
\tlocal adapter = resolve_adapter()
\tif not adapter then
\t\treturn
\tend

\tconfig.type = adapter.name
\tdebug.start(config)
end

local function system(cmd, opts)
\treturn vim.system(cmd, vim.tbl_extend("force", {
\t\ttext = true,
\t\tcwd = workspace_root(),
\t}, opts or {})):wait()
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

local function scan_dir_for_bins(dir)
\tlocal out = {}
\tif not is_dir(dir) then
\t\treturn out
\tend

\tlocal scan = uv.fs_scandir(dir)
\tif not scan then
\t\treturn out
\tend

\twhile true do
\t\tlocal name, typ = uv.fs_scandir_next(scan)
\t\tif not name then
\t\t\tbreak
\t\tend

\t\tlocal path = path_join(dir, name)
\t\tif typ == "file" and fn.executable(path) == 1 then
\t\t\tout[#out + 1] = path
\t\tend
\tend

\ttable.sort(out)
\treturn out
end

local function choose(items, prompt, formatter)
\tif #items == 0 then
\t\treturn nil
\tend

\tlocal choices = { prompt or "Select:" }
\tfor i, item in ipairs(items) do
\t\tlocal label = formatter and formatter(item) or tostring(item)
\t\tchoices[#choices + 1] = string.format("%d. %s", i, label)
\tend

\tlocal idx = fn.inputlist(choices)
\tif idx < 1 or idx > #items then
\t\treturn nil
\tend

\treturn items[idx]
end

local function candidate_programs()
\tlocal items = {}

\tlocal explicit = path_join(zig_out_bin(), project_name())
\tif file_exists(explicit) then
\t\titems[#items + 1] = explicit
\tend

\tfor _, path in ipairs(scan_dir_for_bins(zig_out_bin())) do
\t\tif not vim.tbl_contains(items, path) then
\t\t\titems[#items + 1] = path
\t\tend
\tend

\tfor _, path in ipairs(scan_dir_for_bins(zig_cache_bin())) do
\t\tif not vim.tbl_contains(items, path) then
\t\t\titems[#items + 1] = path
\t\tend
\tend

\treturn items
end

local function resolve_program()
\tlocal candidates = candidate_programs()

\tif #candidates == 1 then
\t\treturn candidates[1]
\tend

\tif #candidates > 1 then
\t\tlocal picked = choose(candidates, "Zig executable:", function(item)
\t\t\treturn item:gsub("^" .. vim.pesc(workspace_root() .. "/"), "")
\t\tend)
\t\tif picked then
\t\t\treturn picked
\t\tend
\tend

\tlocal program = input("Path to Zig executable: ", zig_out_bin() .. "/", "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

function M.build()
\tlocal result = system({ "zig", "build" })
\tif result.code ~= 0 then
\t\tnotify(result.stderr ~= "" and result.stderr or "zig build failed", vim.log.levels.ERROR)
\t\treturn
\tend
\tnotify("zig build complete")
end

function M.build_release()
\tlocal result = system({ "zig", "build", "-Doptimize=ReleaseSafe" })
\tif result.code ~= 0 then
\t\tnotify(result.stderr ~= "" and result.stderr or "zig build release failed", vim.log.levels.ERROR)
\t\treturn
\tend
\tnotify("zig build -Doptimize=ReleaseSafe complete")
end

function M.launch()
\tlocal result = system({ "zig", "build" })
\tif result.code ~= 0 then
\t\tnotify(result.stderr ~= "" and result.stderr or "zig build failed", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Zig executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Zig launch",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "zig" },
\t})
end

function M.launch_current_binary()
\tlocal default = path_join(zig_out_bin(), project_name())
\tlocal program = input("Path to Zig executable: ", default, "file")

\tif program == "" or not file_exists(program) then
\t\tnotify("Zig executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Zig launch executable",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "zig" },
\t})
end

function M.test_current_file()
\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Zig file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tif not executable("zig") then
\t\tnotify("zig not found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal out_name = fn.fnamemodify(file, ":t:r") .. "-test"
\tlocal out_bin = path_join(zig_out_bin(), out_name)

\tfn.mkdir(zig_out_bin(), "p")

\tlocal result = system({
\t\t"zig",
\t\t"test",
\t\t"-femit-bin=" .. out_bin,
\t\t"--test-no-exec",
\t\tfile,
\t})

\tif result.code ~= 0 then
\t\tnotify(result.stderr ~= "" and result.stderr or "zig test build failed", vim.log.levels.ERROR)
\t\treturn
\tend

\tif not file_exists(out_bin) then
\t\tnotify("Compiled Zig test binary not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal zig_bin = fn.exepath("zig")
\tlocal args = {}

\tif zig_bin ~= "" then
\t\targs[#args + 1] = zig_bin
\tend

\tvim.list_extend(args, prompt_args())

\tstart({
\t\trequest = "launch",
\t\tname = "Zig test current file",
\t\tprogram = out_bin,
\t\tcwd = workspace_root(),
\t\targs = args,
\t\tenv = prompt_env(),
\t\tstopOnEntry = false,
\t\tsourceLanguages = { "zig" },
\t})
end

function M.attach_pid()
\tlocal pid = tonumber(input("PID: ", ""))
\tif not pid then
\t\tnotify("Invalid PID", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal program = input("Path to Zig executable (optional): ", zig_out_bin() .. "/", "file")
\tif program == "" then
\t\tprogram = nil
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Zig attach PID",
\t\tpid = pid,
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\tsourceLanguages = { "zig" },
\t})
end

function M.setup()
\tapi.nvim_create_user_command("ZigDapBuild", M.build, {
\t\tdesc = "zig build",
\t})

\tapi.nvim_create_user_command("ZigDapBuildRelease", M.build_release, {
\t\tdesc = "zig build -Doptimize=ReleaseSafe",
\t})

\tapi.nvim_create_user_command("ZigDapLaunch", M.launch, {
\t\tdesc = "Build and debug Zig executable",
\t})

\tapi.nvim_create_user_command("ZigDapExec", M.launch_current_binary, {
\t\tdesc = "Debug selected Zig executable",
\t})

\tapi.nvim_create_user_command("ZigDapTest", M.test_current_file, {
\t\tdesc = "Build and debug Zig test binary for current file",
\t})

\tapi.nvim_create_user_command("ZigDapAttach", M.attach_pid, {
\t\tdesc = "Attach debugger to Zig process",
\t})

\tvim.keymap.set("n", "<leader>zb", M.build, { desc = "Zig DAP build" })
\tvim.keymap.set("n", "<leader>zB", M.build_release, { desc = "Zig DAP build release" })
\tvim.keymap.set("n", "<leader>zd", M.launch, { desc = "Zig DAP launch" })
\tvim.keymap.set("n", "<leader>ze", M.launch_current_binary, { desc = "Zig DAP executable" })
\tvim.keymap.set("n", "<leader>zt", M.test_current_file, { desc = "Zig DAP test" })
\tvim.keymap.set("n", "<leader>za", M.attach_pid, { desc = "Zig DAP attach" })
end

return M