

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "bashdb",
\tcommand = nil,
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.bash" })
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
\t\t".git",
\t\t".envrc",
\t\t"shell.nix",
\t\t"flake.nix",
\t\t"package.json",
\t\t"Makefile",
\t})

\treturn root or cwd()
end

local function joinpath(...)
\treturn vim.fs.joinpath(...)
end

local function data_path()
\treturn fn.stdpath("data")
end

local function mason_pkg_root()
\treturn joinpath(data_path(), "mason", "packages", "bash-debug-adapter")
end

local function default_adapter_command()
\tlocal root = mason_pkg_root()
\tlocal candidates = {
\t\tjoinpath(root, "bash-debug-adapter"),
\t\tjoinpath(root, "extension", "out", "bashDebug.js"),
\t}

\tfor _, path in ipairs(candidates) do
\t\tif file_exists(path) then
\t\t\treturn path
\t\tend
\tend

\treturn nil
end

local function default_bashdb_dir()
\treturn joinpath(mason_pkg_root(), "extension", "bashdb_dir")
end

local function default_bashdb()
\treturn joinpath(default_bashdb_dir(), "bashdb")
end

local function first_executable(paths)
\tfor _, path in ipairs(paths) do
\t\tif executable(path) then
\t\t\treturn path
\t\tend
\tend
\treturn nil
end

local function resolve_path_or_input(prompt_text, default)
\tlocal value = input(prompt_text, default or "", "file")
\tif value == "" then
\t\treturn nil
\tend
\treturn value
end

local function resolve_adapter_command()
\tif M.adapter.command and file_exists(M.adapter.command) then
\t\treturn M.adapter.command
\tend

\tlocal found = default_adapter_command()
\tif found then
\t\tM.adapter.command = found
\t\treturn found
\tend

\treturn resolve_path_or_input("Path to bash-debug-adapter: ", mason_pkg_root() .. "/", "file")
end

local function resolve_bash()
\tlocal env_bash = vim.env.SHELL
\tif env_bash and env_bash ~= "" and executable(env_bash) then
\t\treturn env_bash
\tend

\treturn first_executable({
\t\t"/usr/bin/bash",
\t\t"/bin/bash",
\t\t"/usr/local/bin/bash",
\t})
end

local function resolve_cat()
\treturn first_executable({
\t\t"/usr/bin/cat",
\t\t"/bin/cat",
\t\t"cat",
\t})
end

local function resolve_mkfifo()
\treturn first_executable({
\t\t"/usr/bin/mkfifo",
\t\t"/bin/mkfifo",
\t\t"mkfifo",
\t})
end

local function resolve_pkill()
\treturn first_executable({
\t\t"/usr/bin/pkill",
\t\t"/bin/pkill",
\t\t"/usr/local/bin/pkill",
\t\t"pkill",
\t})
end

local function ensure_adapter()
\tlocal adapter_cmd = resolve_adapter_command()
\tif not adapter_cmd or not file_exists(adapter_cmd) then
\t\tnotify(
\t\t\t"Bash DAP adapter not found.
Install rogalmic Bash Debug / bash-debug-adapter, or set the adapter path manually.",
\t\t\tvim.log.levels.ERROR
\t\t)
\t\treturn false
\tend

\tM.adapter.command = adapter_cmd

\tlocal bashdb = default_bashdb()
\tlocal bashdb_dir = default_bashdb_dir()
\tlocal bash = resolve_bash()
\tlocal cat = resolve_cat()
\tlocal mkfifo = resolve_mkfifo()
\tlocal pkill = resolve_pkill()

\tif not file_exists(bashdb) then
\t\tnotify("bashdb not found: " .. bashdb, vim.log.levels.ERROR)
\t\treturn false
\tend

\tif not file_exists(bashdb_dir) then
\t\tnotify("bashdb lib dir not found: " .. bashdb_dir, vim.log.levels.ERROR)
\t\treturn false
\tend

\tif not bash then
\t\tnotify("bash not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\tif not cat then
\t\tnotify("cat not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\tif not mkfifo then
\t\tnotify("mkfifo not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\tif not pkill then
\t\tnotify("pkill not found in PATH", vim.log.levels.ERROR)
\t\treturn false
\tend

\treturn true
end

local function start(config)
\tif not ensure_adapter() then
\t\treturn
\tend

\tconfig.type = M.adapter.name
\tconfig.pathBashdb = default_bashdb()
\tconfig.pathBashdbLib = default_bashdb_dir()
\tconfig.pathBash = resolve_bash()
\tconfig.pathCat = resolve_cat()
\tconfig.pathMkfifo = resolve_mkfifo()
\tconfig.pathPkill = resolve_pkill()
\tconfig.showDebugOutput = config.showDebugOutput ~= false
\tconfig.trace = config.trace ~= false
\tconfig.terminalKind = config.terminalKind or "integrated"

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

local function candidate_scripts(dir)
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
\t\tif typ == "file" and (name:match("%.sh$") or is_executable(path)) then
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
\tlocal file = current_file()
\tif file ~= "" and file:match("%.sh$") then
\t\treturn file
\tend

\tlocal scripts = candidate_scripts(workspace_root())
\tif #scripts == 1 then
\t\treturn scripts[1]
\tend
\tif #scripts > 1 then
\t\tlocal picked = choose(scripts, "Bash script:")
\t\tif picked then
\t\t\treturn picked
\t\tend
\tend

\tlocal program = input("Path to script: ", workspace_root() .. "/", "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

local function shellcheck()
\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Script not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tif not executable("shellcheck") then
\t\tnotify("shellcheck not found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal result = vim.system({ "shellcheck", program }, {
\t\tcwd = workspace_root(),
\t\ttext = true,
\t}):wait()

\tif result.code == 0 then
\t\tnotify("shellcheck: no issues found")
\t\treturn
\tend

\tlocal msg = (result.stdout and result.stdout ~= "") and result.stdout
\t\tor ((result.stderr and result.stderr ~= "") and result.stderr)
\t\tor "shellcheck reported issues"
\tnotify(msg, vim.log.levels.WARN)
end

function M.run_script()
\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Script not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Bash launch script",
\t\tprogram = program,
\t\tfile = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t})
end

function M.run_file()
\tlocal program = current_file()
\tif program == "" or not file_exists(program) then
\t\tnotify("Current file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Bash launch current file",
\t\tprogram = program,
\t\tfile = program,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t})
end

function M.run_with_xtrace()
\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Script not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal args = { "-x" }
\tvim.list_extend(args, prompt_args())

\tstart({
\t\trequest = "launch",
\t\tname = "Bash launch script (-x)",
\t\tprogram = program,
\t\tfile = program,
\t\tcwd = workspace_root(),
\t\targs = args,
\t\tenv = prompt_env(),
\t})
end

function M.run_selection()
\tlocal scripts = candidate_scripts(workspace_root())
\tlocal picked = choose(scripts, "Bash script:")
\tif not picked or not file_exists(picked) then
\t\tnotify("Script not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Bash launch selected script",
\t\tprogram = picked,
\t\tfile = picked,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t})
end

function M.setup()
\tapi.nvim_create_user_command("BashDapRun", M.run_script, {
\t\tdesc = "Debug bash script",
\t})

\tapi.nvim_create_user_command("BashDapFile", M.run_file, {
\t\tdesc = "Debug current bash file",
\t})

\tapi.nvim_create_user_command("BashDapSelect", M.run_selection, {
\t\tdesc = "Select and debug bash script",
\t})

\tapi.nvim_create_user_command("BashDapTrace", M.run_with_xtrace, {
\t\tdesc = "Debug bash script with -x",
\t})

\tapi.nvim_create_user_command("BashDapCheck", shellcheck, {
\t\tdesc = "Run shellcheck on bash script",
\t})

\tvim.keymap.set("n", "<leader>bd", M.run_script, { desc = "Bash DAP run" })
\tvim.keymap.set("n", "<leader>bf", M.run_file, { desc = "Bash DAP file" })
\tvim.keymap.set("n", "<leader>bs", M.run_selection, { desc = "Bash DAP select" })
\tvim.keymap.set("n", "<leader>bx", M.run_with_xtrace, { desc = "Bash DAP trace" })
\tvim.keymap.set("n", "<leader>bc", shellcheck, { desc = "Bash DAP check" })
end

return M