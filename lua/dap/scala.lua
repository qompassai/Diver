-- ~/.config/nvim/lua/dap/scala.lua

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.scala" })
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

local function input(prompt, default, completion)
\treturn fn.input(prompt, default or "", completion or "")
end

local function workspace_root()
\tlocal file = current_file()
\tlocal start = file ~= "" and file or cwd()

\tlocal root = vim.fs.root(start, {
\t\t"build.sbt",
\t\t"project.scala",
\t\t"build.sc",
\t\t".bsp",
\t\t".metals",
\t\t".git",
\t})

\treturn root or cwd()
end

local function path_to_uri(path)
\treturn vim.uri_from_fname(path)
end

local function buf_lsp_clients(bufnr)
\tlocal clients = vim.lsp.get_clients({ bufnr = bufnr })
\tif #clients == 0 then
\t\tclients = vim.lsp.get_clients()
\tend
\treturn clients
end

local function metals_client(bufnr)
\tfor _, client in ipairs(buf_lsp_clients(bufnr or 0)) do
\t\tif client.name == "metals" then
\t\t\treturn client
\t\tend
\tend
\treturn nil
end

local function has_metals(bufnr)
\treturn metals_client(bufnr) ~= nil
end

local function prompt_args()
\tlocal raw = input("Args: ", "")
\tif raw == "" then
\t\treturn {}
\tend
\treturn vim.split(raw, "%s+", { trimempty = true })
end

local function prompt_jvm_options()
\tlocal raw = input("JVM options: ", "")
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

local function prompt_env_file()
\tlocal env_file = input("Env file (optional): ", "")
\tif env_file == "" then
\t\treturn nil
\tend
\treturn env_file
end

local function lsp_request_sync(client, method, params, timeout_ms)
\tlocal result = client.request_sync(method, params, timeout_ms or 30000, 0)
\tif not result then
\t\treturn nil, "No response from Metals"
\tend
\tif result.err then
\t\treturn nil, result.err.message or "Metals request failed"
\tend
\treturn result.result, nil
end

local function start_uri_adapter(uri, name)
\tdebug.start({
\t\ttype = "scala",
\t\trequest = "attach",
\t\tname = name or "Scala (Metals)",
\t\turi = uri,
\t})
end

local function discover_or_prompt_build_target()
\tlocal target = input("Build target (optional): ", "")
\tif target == "" then
\t\treturn nil
\tend
\treturn target
end

function M.debug_main()
\tlocal bufnr = api.nvim_get_current_buf()
\tlocal client = metals_client(bufnr)
\tif not client then
\t\tnotify("Metals LSP client not attached", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal main_class = input("Main class: ", "")
\tif main_class == "" then
\t\tnotify("Main class is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal params = {
\t\tmainClass = main_class,
\t\tbuildTarget = discover_or_prompt_build_target(),
\t\targs = prompt_args(),
\t\tjvmOptions = prompt_jvm_options(),
\t\tenv = prompt_env(),
\t\tenvFile = prompt_env_file(),
\t}

\tlocal result, err = lsp_request_sync(client, "workspace/executeCommand", {
\t\tcommand = "debug-adapter-start",
\t\targuments = { params },
\t})

\tif err then
\t\tnotify(err, vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal uri = type(result) == "string" and result or (type(result) == "table" and result.uri or nil)
\tif not uri then
\t\tnotify("Metals did not return a debug adapter URI", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart_uri_adapter(uri, "Scala debug main")
end

function M.debug_test_class()
\tlocal bufnr = api.nvim_get_current_buf()
\tlocal client = metals_client(bufnr)
\tif not client then
\t\tnotify("Metals LSP client not attached", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal test_class = input("Test class: ", "")
\tif test_class == "" then
\t\tnotify("Test class is required", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal params = {
\t\ttestClass = test_class,
\t\tbuildTarget = discover_or_prompt_build_target(),
\t\targs = prompt_args(),
\t\tjvmOptions = prompt_jvm_options(),
\t\tenv = prompt_env(),
\t\tenvFile = prompt_env_file(),
\t}

\tlocal result, err = lsp_request_sync(client, "workspace/executeCommand", {
\t\tcommand = "debug-adapter-start",
\t\targuments = { params },
\t})

\tif err then
\t\tnotify(err, vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal uri = type(result) == "string" and result or (type(result) == "table" and result.uri or nil)
\tif not uri then
\t\tnotify("Metals did not return a debug adapter URI", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart_uri_adapter(uri, "Scala debug test class")
end

function M.debug_current_file()
\tlocal bufnr = api.nvim_get_current_buf()
\tlocal client = metals_client(bufnr)
\tif not client then
\t\tnotify("Metals LSP client not attached", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Scala file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal run_type = input("Run type (run|runOrTestFile|testFile|testTarget): ", "runOrTestFile")
\tif run_type == "" then
\t\trun_type = "runOrTestFile"
\tend

\tlocal params = {
\t\tpath = path_to_uri(file),
\t\trunType = run_type,
\t\targs = prompt_args(),
\t\tjvmOptions = prompt_jvm_options(),
\t\tenv = prompt_env(),
\t\tenvFile = prompt_env_file(),
\t}

\tlocal result, err = lsp_request_sync(client, "workspace/executeCommand", {
\t\tcommand = "debug-adapter-start",
\t\targuments = { params },
\t})

\tif err then
\t\tnotify(err, vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal uri = type(result) == "string" and result or (type(result) == "table" and result.uri or nil)
\tif not uri then
\t\tnotify("Metals did not return a debug adapter URI", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart_uri_adapter(uri, "Scala debug current file")
end

function M.run_command_for_file()
\tlocal bufnr = api.nvim_get_current_buf()
\tlocal client = metals_client(bufnr)
\tif not client then
\t\tnotify("Metals LSP client not attached", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal file = current_file()
\tif file == "" or not file_exists(file) then
\t\tnotify("Current Scala file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal run_type = input("Run type (run|runOrTestFile|testFile|testTarget): ", "runOrTestFile")
\tif run_type == "" then
\t\trun_type = "runOrTestFile"
\tend

\tlocal params = {
\t\tpath = path_to_uri(file),
\t\trunType = run_type,
\t\targs = prompt_args(),
\t\tjvmOptions = prompt_jvm_options(),
\t\tenv = prompt_env(),
\t\tenvFile = prompt_env_file(),
\t}

\tlocal result, err = lsp_request_sync(client, "workspace/executeCommand", {
\t\tcommand = "discover-jvm-run-command",
\t\targuments = { params },
\t})

\tif err then
\t\tnotify(err, vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal lines = vim.split(vim.inspect(result), "
", { trimempty = false })
\tvim.cmd("new")
\tlocal buf = api.nvim_get_current_buf()
\tapi.nvim_buf_set_lines(buf, 0, -1, false, lines)
\tvim.bo[buf].filetype = "lua"
\tvim.bo[buf].bufhidden = "wipe"
end

function M.attach_jdwp()
\tlocal host = input("Host: ", "127.0.0.1")
\tif host == "" then
\t\thost = "127.0.0.1"
\tend

\tlocal port = tonumber(input("Port: ", "5005"))
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tdebug.start({
\t\ttype = "scala-jvm",
\t\trequest = "attach",
\t\tname = "Scala attach JDWP",
\t\thostName = host,
\t\tport = port,
\t\tcwd = workspace_root(),
\t})
end

function M.sbt_debug_hint()
\tlocal lines = {
\t\t"Start sbt with a debug port, for example:",
\t\t"sbt -jvm-debug 5005",
\t\t"",
\t\t"Then use :ScalaDapAttach to attach to localhost:5005",
\t}

\tvim.cmd("new")
\tlocal buf = api.nvim_get_current_buf()
\tapi.nvim_buf_set_lines(buf, 0, -1, false, lines)
\tvim.bo[buf].bufhidden = "wipe"
\tvim.bo[buf].filetype = "markdown"
end

function M.trace_files_hint()
\tlocal cache = vim.env.HOME .. "/.cache/metals"
\tlocal lines = {
\t\t"Metals DAP trace files on Linux:",
\t\tcache .. "/dap-server.trace.json",
\t\tcache .. "/dap-client.trace.json",
\t}

\tvim.cmd("new")
\tlocal buf = api.nvim_get_current_buf()
\tapi.nvim_buf_set_lines(buf, 0, -1, false, lines)
\tvim.bo[buf].bufhidden = "wipe"
\tvim.bo[buf].filetype = "markdown"
end

function M.setup()
\tif not has_metals(0) then
\t\tvim.schedule(function()
\t\t\tnotify("Scala DAP prefers Metals. Attach Metals to use debug-adapter-start.", vim.log.levels.INFO)
\t\tend)
\tend

\tapi.nvim_create_user_command("ScalaDapMain", M.debug_main, {
\t\tdesc = "Debug Scala main class via Metals",
\t})

\tapi.nvim_create_user_command("ScalaDapTest", M.debug_test_class, {
\t\tdesc = "Debug Scala test class via Metals",
\t})

\tapi.nvim_create_user_command("ScalaDapFile", M.debug_current_file, {
\t\tdesc = "Debug current Scala file via Metals discovery",
\t})

\tapi.nvim_create_user_command("ScalaRunCommand", M.run_command_for_file, {
\t\tdesc = "Discover JVM shell command for current Scala file",
\t})

\tapi.nvim_create_user_command("ScalaDapAttach", M.attach_jdwp, {
\t\tdesc = "Attach to Scala/JVM JDWP process",
\t})

\tapi.nvim_create_user_command("ScalaSbtDebugHint", M.sbt_debug_hint, {
\t\tdesc = "Show sbt debug attach hint",
\t})

\tapi.nvim_create_user_command("ScalaDapTraceHint", M.trace_files_hint, {
\t\tdesc = "Show Metals DAP trace file paths",
\t})

\tvim.keymap.set("n", "<leader>sm", M.debug_main, { desc = "Scala DAP main" })
\tvim.keymap.set("n", "<leader>st", M.debug_test_class, { desc = "Scala DAP test" })
\tvim.keymap.set("n", "<leader>sf", M.debug_current_file, { desc = "Scala DAP file" })
\tvim.keymap.set("n", "<leader>sr", M.run_command_for_file, { desc = "Scala run command" })
\tvim.keymap.set("n", "<leader>sa", M.attach_jdwp, { desc = "Scala attach JDWP" })
\tvim.keymap.set("n", "<leader>sh", M.sbt_debug_hint, { desc = "Scala sbt debug hint" })
\tvim.keymap.set("n", "<leader>sx", M.trace_files_hint, { desc = "Scala DAP trace hint" })
end

return M