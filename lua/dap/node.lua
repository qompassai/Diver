-- ~/.config/nvim/lua/dap/node.lua
-- Node.js DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "pwa-node",
\tcommand = "node",
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.node" })
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

local function is_dir(path)
\tlocal stat = type(path) == "string" and path ~= "" and uv.fs_stat(path) or nil
\treturn stat and stat.type == "directory" or false
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
\t\t"package.json",
\t\t"tsconfig.json",
\t\t"jsconfig.json",
\t\t".git",
\t})

\treturn root or cwd()
end

local function joinpath(...)
\treturn vim.fs.joinpath(...)
end

local function data_path()
\treturn fn.stdpath("data")
end

local function js_debug_paths()
\tlocal mason_root = joinpath(data_path(), "mason", "packages", "js-debug-adapter")
\treturn {
\t\tjoinpath(mason_root, "js-debug", "src", "dapDebugServer.js"),
\t\tjoinpath(mason_root, "js-debug", "out", "src", "dapDebugServer.js"),
\t}
end

local function resolve_js_debug_server()
\tfor _, path in ipairs(js_debug_paths()) do
\t\tif file_exists(path) then
\t\t\treturn path
\t\tend
\tend

\tlocal default = joinpath(data_path(), "mason", "packages", "js-debug-adapter")
\tlocal picked = input("Path to dapDebugServer.js: ", default .. "/", "file")
\tif picked == "" then
\t\treturn nil
\tend
\treturn picked
end

local function ensure_adapter()
\tif not executable(M.adapter.command) then
\t\tnotify("node not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\tlocal server = resolve_js_debug_server()
\tif not server or not file_exists(server) then
\t\tnotify(
\t\t\t"js-debug adapter not found.
Install js-debug-adapter and ensure dapDebugServer.js is available.",
\t\t\tvim.log.levels.ERROR
\t\t)
\t\treturn false
\tend

\tM.adapter.args = { server, "${port}", "127.0.0.1" }
\treturn true
end

local function start(config)
\tif not ensure_adapter() then
\t\treturn
\tend

\tconfig.type = M.adapter.name
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

local function package_json_path()
\treturn joinpath(workspace_root(), "package.json")
end

local function read_json(path)
\tif not file_exists(path) then
\t\treturn nil
\tend

\tlocal lines = fn.readfile(path)
\tif not lines or vim.tbl_isempty(lines) then
\t\treturn nil
\tend

\tlocal ok, decoded = pcall(vim.json.decode, table.concat(lines, "
"))
\tif not ok or type(decoded) ~= "table" then
\t\treturn nil
\tend

\treturn decoded
end

local function package_json()
\treturn read_json(package_json_path())
end

local function package_scripts()
\tlocal pkg = package_json()
\tif type(pkg) ~= "table" or type(pkg.scripts) ~= "table" then
\t\treturn {}
\tend
\treturn pkg.scripts
end

local function script_names()
\tlocal names = {}
\tfor name, _ in pairs(package_scripts()) do
\t\tnames[#names + 1] = name
\tend
\ttable.sort(names)
\treturn names
end

local function choose(items, prompt)
\tif #items == 0 then
\t\treturn nil
\tend

\tlocal choices = { prompt or "Select:" }
\tfor i, item in ipairs(items) do
\t\tchoices[#choices + 1] = string.format("%d. %s", i, item)
\tend

\tlocal idx = fn.inputlist(choices)
\tif idx < 1 or idx > #items then
\t\treturn nil
\tend

\treturn items[idx]
end

local function candidate_programs(dir)
\tif not is_dir(dir) then
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
\t\tif typ == "file"
\t\t\tand (name:match("%.js$")
\t\t\t\tor name:match("%.cjs$")
\t\t\t\tor name:match("%.mjs$")
\t\t\t\tor name:match("%.ts$")
\t\t\t\tor name:match("%.cts$")
\t\t\t\tor name:match("%.mts$"))
\t\tthen
\t\t\titems[#items + 1] = path
\t\tend
\tend

\ttable.sort(items)
\treturn items
end

local function resolve_program()
\tlocal file = current_file()
\tif file ~= "" and file:match("%.[cm]?[jt]s$") then
\t\treturn file
\tend

\tlocal root = workspace_root()
\tlocal bins = candidate_programs(root)
\tif #bins == 1 then
\t\treturn bins[1]
\tend
\tif #bins > 1 then
\t\tlocal short = {}
\t\tlocal map = {}
\t\tfor _, item in ipairs(bins) do
\t\t\tlocal rel = item:gsub("^" .. vim.pesc(root .. "/"), "")
\t\t\tshort[#short + 1] = rel
\t\t\tmap[rel] = item
\t\tend
\t\tlocal picked = choose(short, "Node program:")
\t\tif picked then
\t\t\treturn map[picked]
\t\tend
\tend

\tlocal program = input("Path to program: ", root .. "/", "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

local function has_local_bin(name)
\treturn file_exists(joinpath(workspace_root(), "node_modules", ".bin", name))
end

local function detect_runtime()
\tif has_local_bin("tsx") then
\t\treturn "tsx"
\tend
\tif has_local_bin("ts-node") then
\t\treturn "ts-node"
\tend
\treturn "node"
end

local function default_skip_files()
\treturn {
\t\t"<node_internals>/**",
\t\tjoinpath(workspace_root(), "node_modules", "**"),
\t}
end

function M.run_file()
\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Program not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal runtime = detect_runtime()
\tlocal ext = fn.fnamemodify(program, ":e")
\tlocal runtime_executable = runtime
\tlocal runtime_args = {}

\tif runtime == "node" and (ext == "ts" or ext == "cts" or ext == "mts") then
\t\tnotify("TypeScript file detected but no tsx/ts-node runtime found", vim.log.levels.WARN)
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Node launch file",
\t\tprogram = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tinternalConsoleOptions = "neverOpen",
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
\t\truntimeExecutable = runtime_executable,
\t\truntimeArgs = runtime_args,
\t})
end

function M.run_npm_script()
\tlocal scripts = script_names()
\tif #scripts == 0 then
\t\tnotify("No package.json scripts found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal script = choose(scripts, "npm script:")
\tif not script then
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Node launch npm script",
\t\tcwd = workspace_root(),
\t\truntimeExecutable = "npm",
\t\truntimeArgs = { "run", script, "--" },
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tinternalConsoleOptions = "neverOpen",
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
\t})
end

function M.attach_port()
\tlocal port = tonumber(input("Port: ", "9229"))
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Node attach port",
\t\taddress = "127.0.0.1",
\t\tport = port,
\t\tcwd = workspace_root(),
\t\trestart = true,
\t\tcontinueOnAttach = true,
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
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
\t\tname = "Node attach PID",
\t\tprocessId = tostring(pid),
\t\tcwd = workspace_root(),
\t\tcontinueOnAttach = true,
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
\t})
end

function M.attach_next_dev()
\tlocal port = tonumber(input("Next inspect port: ", "9229"))
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Node attach Next dev",
\t\taddress = "127.0.0.1",
\t\tport = port,
\t\tcwd = workspace_root(),
\t\trestart = true,
\t\tcontinueOnAttach = true,
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
\t})
end

function M.run_jest()
\tlocal jest = joinpath(workspace_root(), "node_modules", "jest", "bin", "jest.js")
\tif not file_exists(jest) then
\t\tnotify("jest not found in node_modules", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Node debug Jest",
\t\truntimeExecutable = "node",
\t\truntimeArgs = { jest, "--runInBand" },
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tinternalConsoleOptions = "neverOpen",
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
\t})
end

function M.run_mocha()
\tlocal mocha = joinpath(workspace_root(), "node_modules", "mocha", "bin", "mocha.js")
\tif not file_exists(mocha) then
\t\tnotify("mocha not found in node_modules", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Node debug Mocha",
\t\truntimeExecutable = "node",
\t\truntimeArgs = { mocha },
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tinternalConsoleOptions = "neverOpen",
\t\tskipFiles = default_skip_files(),
\t\tsourceMaps = true,
\t\tsmartStep = true,
\t})
end

function M.setup()
\tapi.nvim_create_user_command("NodeDapRun", M.run_file, {
\t\tdesc = "Debug Node file",
\t})

\tapi.nvim_create_user_command("NodeDapScript", M.run_npm_script, {
\t\tdesc = "Debug npm script",
\t})

\tapi.nvim_create_user_command("NodeDapAttach", M.attach_port, {
\t\tdesc = "Attach to Node inspect port",
\t})

\tapi.nvim_create_user_command("NodeDapAttachPid", M.attach_pid, {
\t\tdesc = "Attach to Node process ID",
\t})

\tapi.nvim_create_user_command("NodeDapNext", M.attach_next_dev, {
\t\tdesc = "Attach to Next.js dev server",
\t})

\tapi.nvim_create_user_command("NodeDapJest", M.run_jest, {
\t\tdesc = "Debug Jest tests",
\t})

\tapi.nvim_create_user_command("NodeDapMocha", M.run_mocha, {
\t\tdesc = "Debug Mocha tests",
\t})

\tvim.keymap.set("n", "<leader>nd", M.run_file, { desc = "Node DAP run" })
\tvim.keymap.set("n", "<leader>ns", M.run_npm_script, { desc = "Node DAP script" })
\tvim.keymap.set("n", "<leader>na", M.attach_port, { desc = "Node DAP attach port" })
\tvim.keymap.set("n", "<leader>nA", M.attach_pid, { desc = "Node DAP attach pid" })
\tvim.keymap.set("n", "<leader>nn", M.attach_next_dev, { desc = "Node DAP next" })
\tvim.keymap.set("n", "<leader>nj", M.run_jest, { desc = "Node DAP jest" })
\tvim.keymap.set("n", "<leader>nm", M.run_mocha, { desc = "Node DAP mocha" })
end

return M