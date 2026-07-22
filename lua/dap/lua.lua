-- ~/.config/nvim/lua/dap/lua.lua
-- Lua DAP configuration for Neovim 0.13 built-in vim.debug, no plugins
--
-- Targets:
-- - Plain Lua files
-- - LuaJIT
-- - Project-local execution
-- - Optional attach/remote config for lua-debug style workflows
--
-- This module assumes you have a working standalone Lua debug adapter available.
-- The most practical choice is actboy168/lua-debug.

local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local debug = vim.debug

local M = {}

M.adapter = {
\tname = "lua",
\tcommand = "lua-debug",
}

M.configurations = {
\tlua = {},
}

local function notify(msg, level)
\tvim.notify(msg, level or vim.log.levels.INFO, { title = "dap.lua" })
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

local function current_dir()
\tlocal file = current_file()
\tif file == "" then
\t\treturn cwd()
\tend
\treturn fn.fnamemodify(file, ":p:h")
end

local function workspace_root()
\tlocal file = current_file()
\tif file == "" then
\t\treturn cwd()
\tend

\tlocal root_markers = {
\t\t".git",
\t\t".luarc.json",
\t\t".luarc.jsonc",
\t\t"selene.toml",
\t\t"stylua.toml",
\t\t".stylua.toml",
\t\t"init.lua",
\t}

\tlocal root = vim.fs.root(file, root_markers)
\treturn root or cwd()
end

local function file_exists(path)
\treturn type(path) == "string" and path ~= "" and uv.fs_stat(path) ~= nil
end

local function lua_bin()
\tif executable("luajit") then
\t\treturn "luajit"
\tend
\tif executable("lua") then
\t\treturn "lua"
\tend
\treturn nil
end

local function resolve_program()
\tlocal file = current_file()
\tif file ~= "" then
\t\treturn file
\tend

\tlocal program = input("Lua program: ", cwd() .. "/", "file")
\tif program == "" then
\t\treturn nil
\tend
\treturn program
end

local function resolve_args()
\tlocal raw = input("Args: ", "")
\tif raw == "" then
\t\treturn {}
\tend
\treturn vim.split(raw, "%s+", { trimempty = true })
end

local function resolve_host()
\tlocal host = input("Host: ", "127.0.0.1")
\tif host == "" then
\t\treturn "127.0.0.1"
\tend
\treturn host
end

local function resolve_port(default)
\tlocal port = tonumber(input("Port: ", tostring(default or 8818)))
\tif not port then
\t\treturn nil
\tend
\treturn port
end

local function ensure_adapter()
\tif executable(M.adapter.command) then
\t\treturn true
\tend

\tnotify(
\t\t("Lua DAP adapter not found: %s
Install/build a standalone adapter such as actboy168/lua-debug and make it available in PATH.")
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

function M.launch_file()
\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Lua program not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal lua = lua_bin()
\tif not lua then
\t\tnotify("Neither lua nor luajit was found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Launch current Lua file",
\t\tcwd = workspace_root(),
\t\tprogram = program,
\t\truntimeExecutable = lua,
\t\targs = resolve_args(),
\t\tstopOnEntry = false,
\t})
end

function M.launch_project_main()
\tlocal root = workspace_root()
\tlocal candidates = {
\t\troot .. "/main.lua",
\t\troot .. "/init.lua",
\t\troot .. "/lua/main.lua",
\t}

\tlocal program
\tfor _, candidate in ipairs(candidates) do
\t\tif file_exists(candidate) then
\t\t\tprogram = candidate
\t\t\tbreak
\t\tend
\tend

\tif not program then
\t\tprogram = input("Project entry Lua file: ", root .. "/", "file")
\tend

\tif not program or program == "" or not file_exists(program) then
\t\tnotify("Project entry Lua file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal lua = lua_bin()
\tif not lua then
\t\tnotify("Neither lua nor luajit was found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Launch Lua project",
\t\tcwd = root,
\t\tprogram = program,
\t\truntimeExecutable = lua,
\t\targs = resolve_args(),
\t\tstopOnEntry = false,
\t})
end

function M.launch_with_luajit()
\tlocal program = resolve_program()
\tif not program or not file_exists(program) then
\t\tnotify("Lua program not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tif not executable("luajit") then
\t\tnotify("luajit not found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Launch with LuaJIT",
\t\tcwd = workspace_root(),
\t\tprogram = program,
\t\truntimeExecutable = "luajit",
\t\targs = resolve_args(),
\t\tstopOnEntry = false,
\t})
end

function M.attach_remote()
\tlocal host = resolve_host()
\tlocal port = resolve_port(8818)
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Attach to remote Lua",
\t\thost = host,
\t\tport = port,
\t\tcwd = workspace_root(),
\t})
end

function M.attach_local_socket()
\tlocal port = resolve_port(8818)
\tif not port then
\t\tnotify("Invalid port", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "attach",
\t\tname = "Attach to local Lua debug server",
\t\thost = "127.0.0.1",
\t\tport = port,
\t\tcwd = workspace_root(),
\t})
end

function M.debug_neovim_lua()
\tlocal init = fn.stdpath("config") .. "/init.lua"
\tlocal target = current_file()

\tif target == "" then
\t\ttarget = init
\tend

\tif not file_exists(target) then
\t\tnotify("Target file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal nvim = fn.exepath("nvim")
\tif nvim == "" then
\t\tnotify("nvim executable not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Debug Neovim Lua file",
\t\tcwd = workspace_root(),
\t\tprogram = target,
\t\truntimeExecutable = nvim,
\t\targs = {
\t\t\t"--clean",
\t\t\t"-l",
\t\t\ttarget,
\t\t},
\t\tstopOnEntry = false,
\t})
end

function M.debug_busted()
\tlocal root = workspace_root()

\tif not executable("busted") then
\t\tnotify("busted not found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tlocal file = current_file()
\tif file == "" then
\t\tfile = input("Busted test file: ", root .. "/tests/", "file")
\tend

\tif file == "" or not file_exists(file) then
\t\tnotify("Busted test file not found", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Debug busted test",
\t\tcwd = root,
\t\tprogram = file,
\t\truntimeExecutable = "busted",
\t\targs = { file },
\t\tstopOnEntry = false,
\t})
end

function M.debug_one_shot()
\tlocal expr = input("Lua expression: ", "print(vim.inspect(vim.version()))")
\tif expr == "" then
\t\treturn
\tend

\tlocal temp = fn.tempname() .. ".lua"
\tfn.writefile({ expr }, temp)

\tlocal lua = lua_bin()
\tif not lua then
\t\tnotify("Neither lua nor luajit was found in PATH", vim.log.levels.ERROR)
\t\treturn
\tend

\tstart({
\t\trequest = "launch",
\t\tname = "Debug Lua expression",
\t\tcwd = current_dir(),
\t\tprogram = temp,
\t\truntimeExecutable = lua,
\t\targs = {},
\t\tstopOnEntry = true,
\t})
end

function M.setup()
\tapi.nvim_create_user_command("LuaDapLaunchFile", M.launch_file, {
\t\tdesc = "Debug current Lua file",
\t})

\tapi.nvim_create_user_command("LuaDapLaunchProject", M.launch_project_main, {
\t\tdesc = "Debug Lua project entry file",
\t})

\tapi.nvim_create_user_command("LuaDapLaunchJit", M.launch_with_luajit, {
\t\tdesc = "Debug Lua file with LuaJIT",
\t})

\tapi.nvim_create_user_command("LuaDapAttach", M.attach_local_socket, {
\t\tdesc = "Attach to local Lua debug server",
\t})

\tapi.nvim_create_user_command("LuaDapAttachRemote", M.attach_remote, {
\t\tdesc = "Attach to remote Lua debug server",
\t})

\tapi.nvim_create_user_command("LuaDapNeovim", M.debug_neovim_lua, {
\t\tdesc = "Debug Lua using Neovim as the runtime",
\t})

\tapi.nvim_create_user_command("LuaDapBusted", M.debug_busted, {
\t\tdesc = "Debug current busted test file",
\t})

\tapi.nvim_create_user_command("LuaDapExpr", M.debug_one_shot, {
\t\tdesc = "Debug a one-shot Lua expression",
\t})

\tvim.keymap.set("n", "<leader>ul", M.launch_file, { desc = "Lua DAP launch file" })
\tvim.keymap.set("n", "<leader>up", M.launch_project_main, { desc = "Lua DAP launch project" })
\tvim.keymap.set("n", "<leader>uj", M.launch_with_luajit, { desc = "Lua DAP launch LuaJIT" })
\tvim.keymap.set("n", "<leader>ua", M.attach_local_socket, { desc = "Lua DAP attach" })
\tvim.keymap.set("n", "<leader>uA", M.attach_remote, { desc = "Lua DAP attach remote" })
\tvim.keymap.set("n", "<leader>un", M.debug_neovim_lua, { desc = "Lua DAP Neovim runtime" })
\tvim.keymap.set("n", "<leader>ut", M.debug_busted, { desc = "Lua DAP busted" })
\tvim.keymap.set("n", "<leader>ux", M.debug_one_shot, { desc = "Lua DAP expression" })
end

return M