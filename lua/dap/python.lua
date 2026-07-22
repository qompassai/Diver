-- ~/.config/nvim/lua/dap/python.lua
-- Python DAP configuration for Neovim 0.13 built-in vim.debug, no plugins

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "debugpy",
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.python" })
end

local function cwd()
\treturn fn.getcwd()
end

local function input(prompt, default, completion)
\treturn fn.input(prompt, default or "", completion or "")
end

local function executable(cmd)
\treturn fn.executable(cmd) == 1
end

local function file_exists(path)
\treturn type(path) == "string" and path ~= "" and uv.fs_stat(path) ~= nil
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
\t\t"pyproject.toml",
\t\t"setup.py",
\t\t"setup.cfg",
\t\t"requirements.txt",
\t\t".venv",
\t\t"venv",
\t\t".git",
\t})

\treturn root or cwd()
end

local function path_join(...)
\treturn table.concat({ ... }, "/")
end

local function is_windows()
\treturn uv.os_uname().sysname == "Windows_NT"
end

local function venv_python(root)
\tif is_windows() then
\t\tlocal candidates = {
\t\t\tpath_join(root, ".venv", "Scripts", "python.exe"),
\t\t\tpath_join(root, "venv", "Scripts", "python.exe"),
\t\t}
\t\tfor _, path in ipairs(candidates) do
\t\t\tif file_exists(path) then
\t\t\t\treturn path
\t\t\tend
\t\tend
\telse
\t\tlocal candidates = {
\t\t\tpath_join(root, ".venv", "bin", "python"),
\t\t\tpath_join(root, "venv", "bin", "python"),
\t\t}
\t\tfor _, path in ipairs(candidates) do
\t\t\tif file_exists(path) then
\t\t\t\treturn path
\t\t\tend
\t\tend
\tend
\treturn nil
end

local function resolve_python()
\tlocal root = workspace_root()
\tlocal from_venv = venv_python(root)
\tif from_venv then
\t\treturn from_venv
\tend

\tlocal env_python = vim.env.VIRTUAL_ENV
\tif env_python and env_python ~= "" then
\t\tif is_windows() then
\t\t\tlocal path = path_join(env_python, "Scripts", "python.exe")
\t\t\tif file_exists(path) then
\t\t\t\treturn path
\t\t\tend
\t\telse
\t\t\tlocal path = path_join(env_python, "bin", "python")
\t\t\tif file_exists(path) then
\t\t\t\treturn path
\t\t\tend
\t\tend
\tend

\tif executable("python3") then
\t\treturn "python3"
\tend
\tif executable("python") then
\t\treturn "python"
\tend

\treturn nil
end

local function ensure_python()
\tlocal py = resolve_python()
\tif not py then
\t\tnotify("No Python interpreter found", vim.log.levels.ERROR)
\t\treturn nil
\tend
\treturn py
end

local function ensure_debugpy(py)
\tlocal result = vim.system({ py, "-c", "import debugpy" }, { text = true }):wait()
\tif result.code == 0 then
\t\treturn true
\tend

\tnotify(
\t\t("debugpy is not installed for %s
Install it with: %s -m pip install --upgrade debugpy")
\t\t\t:format(py, py),
\t\tvim.log.levels.ERROR
\t)
\treturn false
end

local function start(config)
\tlocal py = ensure_python()
\tif not py then
\t\treturn
\tend
\tif not ensure_debugpy(py) then
\t\treturn
\tend

\tconfig.type = M.adapter.name
\tconfig.python = py
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

local function prompt_port(default)
\tlocal port = tonumber(input("Port: ", tostring(default or 5678)))
\tif not port then
\t\treturn nil
\tend
\treturn port
end

local function prompt_host(default)
\tlocal host = input("Host: ", default or "127.0.0.1")
\tif host == "" then
\t\treturn "127.0.0.1"
\tend
\treturn host
end

local function module_name_from_file(file, root)
\tif file == "" or root == "" then
\t\treturn nil
\tend

\tlocal rel = fn.fnamemodify(file, ":.")
\tif rel == file then
\t\trel = file:gsub("^" .. vim.pesc(root .. "/"), "")
\tend

\trel = rel:gsub("%.py$", "")
\trel = rel:gsub("/", ".")
\trel = rel:gsub("\\", ".")
\trel = rel:gsub("^src%.", "")

\tif rel == "" then
\t\treturn nil
\tend

\treturn rel
end

function M.launch_file()
\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Python file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Python launch file",
\t\tprogram = file,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = true,
\t\tstopOnEntry = false,
\t})
end

function M.launch_file_all_code()
\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Python file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Python launch file (all code)",
\t\tprogram = file,
\t\tcwd = workspace_root(),
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = false,
\t\tstopOnEntry = false,
\t})
end

function M.launch_module()
\tlocal file = current_file()
\tlocal root = workspace_root()
\tlocal default_module = module_name_from_file(file, root) or ""
\tlocal module = input("Python module: ", default_module)

\tif module == "" then
\t\tnotify("No module specified", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Python launch module",
\t\tmodule = module,
\t\tcwd = root,
\t\targs = prompt_args(),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = true,
\t\tstopOnEntry = false,
\t})
end

function M.launch_pytest()
\tlocal root = workspace_root()
\tlocal target = current_file()

\tif target == "" then
\t\ttarget = input("pytest target: ", root, "file")
\tend
\tif target == "" then
\t\tnotify("No pytest target specified", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Python pytest",
\t\tmodule = "pytest",
\t\tcwd = root,
\t\targs = vim.list_extend({ target }, prompt_args()),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = false,
\t\tstopOnEntry = false,
\t})
end

function M.launch_unittest()
\tlocal root = workspace_root()
\tlocal target = input("unittest module or path: ", current_file() ~= "" and current_file() or root)

\tif target == "" then
\t\tnotify("No unittest target specified", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Python unittest",
\t\tmodule = "unittest",
\t\tcwd = root,
\t\targs = vim.list_extend({ target }, prompt_args()),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = false,
\t\tstopOnEntry = false,
\t})
end

function M.launch_django()
\tlocal root = workspace_root()
\tlocal manage = path_join(root, "manage.py")

\tif not file_exists(manage) then
\t\tmanage = input("manage.py path: ", root .. "/", "file")
\tend
\tif manage == "" or not file_exists(manage) then
\t\tnotify("manage.py not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Python Django runserver",
\t\tprogram = manage,
\t\tcwd = root,
\t\targs = vim.list_extend({ "runserver" }, prompt_args()),
\t\tenv = prompt_env(),
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = true,
\t\tdjango = true,
\t\tstopOnEntry = false,
\t})
end

function M.launch_flask()
\tlocal root = workspace_root()
\tlocal app = input("FLASK_APP: ", "app.py")

\tif app == "" then
\t\tnotify("FLASK_APP is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal env = prompt_env()
\tenv.FLASK_APP = app

\tstart({
\t\trequest = "launch",
\t\tname = "Python Flask",
\t\tmodule = "flask",
\t\tcwd = root,
\t\targs = vim.list_extend({ "run", "--no-debugger" }, prompt_args()),
\t\tenv = env,
\t\tconsole = "integratedTerminal",
\t\tjustMyCode = true,
\t\tjinja = true,
\t\tstopOnEntry = false,
\t})
end

function M.attach_socket()
\tlocal root = workspace_root()
\tlocal host = prompt_host("127.0.0.1")
\tlocal port = prompt_port(5678)

\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Python attach socket",
\t\tconnect = {
\t\t\thost = host,
\t\t\tport = port,
\t\t},
\t\tpathMappings = {
\t\t\t{
\t\t\t\tlocalRoot = root,
\t\t\t\tremoteRoot = ".",
\t\t\t},
\t\t},
\t\tjustMyCode = false,
\t})
end

function M.attach_pid()
\tlocal py = ensure_python()
\tif not py then
\t\treturn
\tend
\tif not ensure_debugpy(py) then
\t\treturn
\tend

\tlocal pid = tonumber(input("PID: ", ""))
\tif not pid then
\t\tnotify("Invalid PID", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal port = prompt_port(5678)
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal result = vim.system({
\t\tpy,
\t\t"-m",
\t\t"debugpy",
\t\t"--listen",
\t\ttostring(port),
\t\t"--pid",
\t\ttostring(pid),
\t}, {
\t\ttext = true,
\t}):wait()

\tif result.code ~= 0 then
\t\tlocal stderr = (result.stderr and result.stderr ~= "") and result.stderr or "Failed to inject debugpy into process"
\t\tnotify(stderr, vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Python attach PID",
\t\tconnect = {
\t\t\thost = "127.0.0.1",
\t\t\tport = port,
\t\t},
\t\tpathMappings = {
\t\t\t{
\t\t\t\tlocalRoot = workspace_root(),
\t\t\t\tremoteRoot = ".",
\t\t\t},
\t\t},
\t\tjustMyCode = false,
\t})
end

function M.run_with_wait()
\tlocal py = ensure_python()
\tif not py then
\t\treturn
\tend
\tif not ensure_debugpy(py) then
\t\treturn
\tend

\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Python file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal port = prompt_port(5678)
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal cmd = {
\t\tpy,
\t\t"-m",
\t\t"debugpy",
\t\t"--listen",
\t\ttostring(port),
\t\t"--wait-for-client",
\t\tfile,
\t}
\tvim.list_extend(cmd, prompt_args())

\tvim.cmd("botright split")
\tvim.fn.termopen(cmd, { cwd = workspace_root() })
\tnotify(("Started debugpy wait-for-client on port %d"):format(port))
end

function M.setup()
\tapi.nvim_create_user_command("PythonDapFile", M.launch_file, {
\t\tdesc = "Debug current Python file",
\t})

\tapi.nvim_create_user_command("PythonDapFileAll", M.launch_file_all_code, {
\t\tdesc = "Debug current Python file with library code",
\t})

\tapi.nvim_create_user_command("PythonDapModule", M.launch_module, {
\t\tdesc = "Debug Python module",
\t})

\tapi.nvim_create_user_command("PythonDapPytest", M.launch_pytest, {
\t\tdesc = "Debug pytest target",
\t})

\tapi.nvim_create_user_command("PythonDapUnitTest", M.launch_unittest, {
\t\tdesc = "Debug unittest target",
\t})

\tapi.nvim_create_user_command("PythonDapDjango", M.launch_django, {
\t\tdesc = "Debug Django runserver",
\t})

\tapi.nvim_create_user_command("PythonDapFlask", M.launch_flask, {
\t\tdesc = "Debug Flask app",
\t})

\tapi.nvim_create_user_command("PythonDapAttach", M.attach_socket, {
\t\tdesc = "Attach to debugpy socket",
\t})

\tapi.nvim_create_user_command("PythonDapAttachPid", M.attach_pid, {
\t\tdesc = "Inject debugpy into PID and attach",
\t})

\tapi.nvim_create_user_command("PythonDapWait", M.run_with_wait, {
\t\tdesc = "Run current file with debugpy --wait-for-client",
\t})

\tvim.keymap.set("n", "<leader>pf", M.launch_file, { desc = "Python DAP file" })
\tvim.keymap.set("n", "<leader>pF", M.launch_file_all_code, { desc = "Python DAP file all code" })
\tvim.keymap.set("n", "<leader>pm", M.launch_module, { desc = "Python DAP module" })
\tvim.keymap.set("n", "<leader>pt", M.launch_pytest, { desc = "Python DAP pytest" })
\tvim.keymap.set("n", "<leader>pu", M.launch_unittest, { desc = "Python DAP unittest" })
\tvim.keymap.set("n", "<leader>pd", M.launch_django, { desc = "Python DAP django" })
\tvim.keymap.set("n", "<leader>pl", M.launch_flask, { desc = "Python DAP flask" })
\tvim.keymap.set("n", "<leader>pa", M.attach_socket, { desc = "Python DAP attach" })
\tvim.keymap.set("n", "<leader>pA", M.attach_pid, { desc = "Python DAP attach pid" })
\tvim.keymap.set("n", "<leader>pw", M.run_with_wait, { desc = "Python DAP wait" })
end

return M