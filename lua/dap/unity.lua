-- ~/.config/nvim/lua/dap/unity.lua
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "coreclr",
\tcommand = "netcoredbg",
\targs = { "--interpreter=vscode" },
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.unity" })
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
\t\t"Assets",
\t\t"Packages",
\t\t"ProjectSettings",
\t\t"*.sln",
\t\t".git",
\t})

\treturn root or cwd()
end

local function ensure_adapter()
\tif executable(M.adapter.command) then
\t\treturn true
\tend

\tnotify(
\t\t("Unity debugger not found: %s
Install Samsung/netcoredbg and put it in PATH.")
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
\tconfig.adapter = {
\t\ttype = "executable",
\t\tcommand = M.adapter.command,
\t\targs = M.adapter.args,
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

local function unity_root()
\tlocal root = workspace_root()
\tif is_dir(path_join(root, "Assets")) and is_dir(path_join(root, "ProjectSettings")) then
\t\treturn root
\tend
\treturn root
end

local function dll_candidates(root)
\tlocal product = fn.fnamemodify(root, ":t")
\treturn {
\t\tpath_join(root, "Library", "ScriptAssemblies", "Assembly-CSharp.dll"),
\t\tpath_join(root, "Library", "ScriptAssemblies", "Assembly-CSharp-Editor.dll"),
\t\tpath_join(root, "Build", product .. ".dll"),
\t\tpath_join(root, product .. ".dll"),
\t}
end

local function guess_unity_dll()
\tlocal root = unity_root()
\tfor _, dll in ipairs(dll_candidates(root)) do
\t\tif file_exists(dll) then
\t\t\treturn dll
\t\tend
\tend
\treturn path_join(root, "Library", "ScriptAssemblies", "Assembly-CSharp.dll")
end

local function prompt_program()
\tlocal dll = input("Path to Unity managed DLL: ", guess_unity_dll(), "file")
\tif dll == "" then
\t\treturn nil
\tend
\treturn dll
end

local function pick_pid_from_ps()
\tlocal cmd = [[ps -eo pid=,comm= | grep -Ei 'Unity|UnityHub|mono|dotnet' | head -n 50]]
\tlocal result = vim.system({ "sh", "-c", cmd }, { text = true }):wait()

\tif result.code ~= 0 or not result.stdout or result.stdout == "" then
\t\treturn nil
\tend

\tlocal lines = vim.split(vim.trim(result.stdout), "
", { trimempty = true })
\tif #lines == 0 then
\t\treturn nil
\tend

\tlocal choices = { "Select Unity/.NET process:" }
\tfor i, line in ipairs(lines) do
\t\tchoices[#choices + 1] = string.format("%d. %s", i, vim.trim(line))
\tend

\tlocal idx = fn.inputlist(choices)
\tif idx < 1 or idx > #lines then
\t\treturn nil
\tend

\tlocal pid = tonumber(vim.trim(lines[idx]):match("^(%d+)"))
\treturn pid
end

function M.launch_dll()
\tlocal program = prompt_program()
\tif not program or program == "" then
\t\tnotify("Managed DLL path is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Unity launch managed DLL",
\t\tprogram = program,
\t\tcwd = unity_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tstopAtEntry = false,
\t\tconsole = "internalConsole",
\t})
end

function M.attach_pid()
\tlocal pid = pick_pid_from_ps()
\tif not pid then
\t\tpid = tonumber(input("PID: ", ""))
\tend

\tif not pid then
\t\tnotify("Invalid PID", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Unity attach PID",
\t\tprocessId = pid,
\t\tcwd = unity_root(),
\t})
end

function M.attach_server()
\tlocal port = tonumber(input("Port: ", "4711"))
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tdebug.start({
\t\ttype = "unity-server",
\t\trequest = "attach",
\t\tname = "Unity attach server",
\t\thost = input("Host: ", "127.0.0.1"),
\t\tport = port,
\t})
end

function M.open_script_assemblies()
\tlocal root = unity_root()
\tlocal dir = path_join(root, "Library", "ScriptAssemblies")

\tif not is_dir(dir) then
\t\tnotify("Library/ScriptAssemblies not found", vim.log.levels.WARN)
\t\treturn
\tend

\tvim.cmd("edit " .. fn.fnameescape(dir))
end

function M.unity_info()
\tlocal root = unity_root()
\tlocal lines = {
\t\t"Unity DAP notes",
\t\t"",
\t\t"Project root: " .. root,
\t\t"Managed assembly guess: " .. guess_unity_dll(),
\t\t"",
\t\t"Recommended workflow:",
\t\t"- Use your C# LSP for code intelligence.",
\t\t"- Let Unity generate .sln/.csproj files.",
\t\t"- Use :UnityDapAttach for a running Unity-related process.",
\t\t"- Use :UnityDapLaunch if you specifically want to launch a managed DLL.",
\t\t"",
\t\t"Adapter:",
\t\t"- netcoredbg --interpreter=vscode",
\t}

\tvim.cmd("new")
\tlocal buf = api.nvim_get_current_buf()
\tapi.nvim_buf_set_lines(buf, 0, -1, false, lines)
\tvim.bo[buf].bufhidden = "wipe"
\tvim.bo[buf].filetype = "markdown"
end

function M.setup()
\tapi.nvim_create_user_command("UnityDapLaunch", M.launch_dll, {
\t\tdesc = "Launch Unity managed DLL with netcoredbg",
\t})

\tapi.nvim_create_user_command("UnityDapAttach", M.attach_pid, {
\t\tdesc = "Attach to running Unity/.NET process",
\t})

\tapi.nvim_create_user_command("UnityDapServer", M.attach_server, {
\t\tdesc = "Attach to Unity debug server/port",
\t})

\tapi.nvim_create_user_command("UnityScriptAssemblies", M.open_script_assemblies, {
\t\tdesc = "Open Unity Library/ScriptAssemblies directory",
\t})

\tapi.nvim_create_user_command("UnityDapInfo", M.unity_info, {
\t\tdesc = "Show Unity DAP info",
\t})

\tvim.keymap.set("n", "<leader>ul", M.launch_dll, { desc = "Unity DAP launch" })
\tvim.keymap.set("n", "<leader>ua", M.attach_pid, { desc = "Unity DAP attach" })
\tvim.keymap.set("n", "<leader>us", M.attach_server, { desc = "Unity DAP server" })
\tvim.keymap.set("n", "<leader>ui", M.unity_info, { desc = "Unity DAP info" })
end

return M