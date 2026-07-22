-- /qompassai/Diver/lua/dap/init.lua
-- Qompass AI Diver Dap Config
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- ----------------------------------------
-- 'bash-debug-adapter' --outdated ---@source https://github.com/rogalmic/vscode-bash-debug

--[[
android.lua
ansible.lua
apache_camel.lua
apex.lua
ballerina.lua
bash.lua
c.lua
cpp.lua
c_cpp.lua
c_cpp_rust.lua
c_cpp_rust_midas.lua
csharp.lua
cobol.lua
cordova.lua
crystal.lua
dart.lua
debug.lua
chrome.lua
dotnet.lua
edge.lua
electron.lua
elixir.lua
emulicious.lua
erlang_edb.lua
erlang_ls.lua
esp32.lua
firefox.lua
firefox_remote.lua
flash.lua
flutter.lua
fortran.lua
gdscript.lua
go.lua
godot.lua
harbour.lua
haskell.lua
haskell_phoityne.lua
haxe_eval.lua
hashlink.lua
hxcpp.lua
java.lua
javascript.lua
javascript_timetravel.lua
jsir.lua
karate.lua
kotlin.lua
latex.lua
lldb.lua
lldb_dap.lua
lua.lua
luau.lua
mock.lua
mono.lua
nativescript.lua
node.lua
objectivec.lua
ocaml.lua
onescript.lua
openqasm.lua
papyrus.lua
perl.lua
perl_languageserver.lua
php.lua
powershell.lua
puppet.lua
python.lua
r.lua
react_native.lua
ruby.lua
ruby_byebug.lua
ruby_lsp.lua
ruby_rdbg.lua
rust.lua
rust_embedded.lua
scala.lua
squirrel.lua
swi_prolog.lua
swf.lua
tla.lua
unity.lua
varphi.lua
vdm.lua
z80.lua
--]]

local api = vim.api
local fn = vim.fn
local debug = vim.debug

local M = {}
pcall(function()
\trequire("dap.rust").setup()
end)
---@type table<string, integer>
local namespaces = {}

---@param name string
---@return integer
local function namespace(name)
\tlocal existing = namespaces[name]
\tif existing then
\t\treturn existing
\tend

\tlocal ns = api.nvim_create_namespace("qompass.dap." .. name)
\tnamespaces[name] = ns
\treturn ns
end

local signs_defined = false

local function define_signs()
\tif signs_defined then
\t\treturn
\tend

\tfn.sign_define("DapBreakpoint", {
\t\ttext = "●",
\t\ttexthl = "DiagnosticSignError",
\t\tlinehl = "",
\t\tnumhl = "",
\t})

\tfn.sign_define("DapBreakpointCondition", {
\t\ttext = "◆",
\t\ttexthl = "DiagnosticSignWarn",
\t\tlinehl = "",
\t\tnumhl = "",
\t})

\tfn.sign_define("DapLogPoint", {
\t\ttext = "▶",
\t\ttexthl = "DiagnosticSignInfo",
\t\tlinehl = "",
\t\tnumhl = "",
\t})

\tfn.sign_define("DapStopped", {
\t\ttext = "→",
\t\ttexthl = "DiagnosticSignHint",
\t\tlinehl = "Visual",
\t\tnumhl = "DiagnosticSignHint",
\t})

\tsigns_defined = true
end

---@param bufnr integer
---@param lnum integer
---@param opts? { condition?: string, log_message?: string }
local function place_breakpoint_sign(bufnr, lnum, opts)
\tlocal sign = "DapBreakpoint"

\tif opts and opts.condition and opts.condition ~= "" then
\t\tsign = "DapBreakpointCondition"
\telseif opts and opts.log_message and opts.log_message ~= "" then
\t\tsign = "DapLogPoint"
\tend

\tfn.sign_place(
\t\t0,
\t\t"qompass-dap-breakpoints",
\t\tsign,
\t\tbufnr,
\t\t{ lnum = lnum, priority = 60 }
\t)
end

---@param bufnr integer
local function refresh_breakpoint_signs(bufnr)
\tif not api.nvim_buf_is_valid(bufnr) then
\t\treturn
\tend

\tfn.sign_unplace("qompass-dap-breakpoints", { buffer = bufnr })

\tlocal breakpoints = debug.get_breakpoints and debug.get_breakpoints(bufnr) or nil
\tif type(breakpoints) ~= "table" then
\t\treturn
\tend

\tfor _, bp in ipairs(breakpoints) do
\t\tlocal lnum = bp.line or bp.lnum or bp[1]
\t\tif type(lnum) == "number" and lnum > 0 then
\t\t\tplace_breakpoint_sign(bufnr, lnum, {
\t\t\t\tcondition = bp.condition,
\t\t\t\tlog_message = bp.logMessage or bp.log_message,
\t\t\t})
\t\tend
\tend
end

local function refresh_all_breakpoint_signs()
\tfor _, bufnr in ipairs(api.nvim_list_bufs()) do
\t\tif api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
\t\t\trefresh_breakpoint_signs(bufnr)
\t\tend
\tend
end

local function clear_stopped_signs()
\tfn.sign_unplace("qompass-dap-stopped")
end

---@param session any
local function place_stopped_sign(session)
\tclear_stopped_signs()

\tif not session or not session.current_frame then
\t\treturn
\tend

\tlocal frame = session.current_frame
\tlocal source = frame.source or {}
\tlocal path = source.path

\tif type(path) ~= "string" or path == "" then
\t\treturn
\tend

\tlocal bufnr = fn.bufadd(path)
\tfn.bufload(bufnr)

\tlocal lnum = frame.line
\tif type(lnum) ~= "number" or lnum < 1 then
\t\treturn
\tend

\tfn.sign_place(
\t\t0,
\t\t"qompass-dap-stopped",
\t\t"DapStopped",
\t\tbufnr,
\t\t{ lnum = lnum, priority = 100 }
\t)
end

local function prompt_program()
\treturn fn.input("Program: ", fn.getcwd() .. "/", "file")
end

local function prompt_args()
\tlocal line = fn.input("Args: ")
\tif line == nil or line == "" then
\t\treturn {}
\tend
\treturn vim.split(line, "%s+", { trimempty = true })
end

local function prompt_cwd()
\tlocal cwd = fn.input("Cwd: ", fn.getcwd(), "dir")
\tif cwd == nil or cwd == "" then
\t\treturn fn.getcwd()
\tend
\treturn cwd
end

---@param adapter string
---@param config table
local function start(adapter, config)
\tconfig.type = adapter
\tdebug.start(config)
end

function M.toggle_breakpoint()
\tdefine_signs()
\tdebug.toggle_breakpoint()
\trefresh_all_breakpoint_signs()
end

function M.set_conditional_breakpoint()
\tdefine_signs()
\tlocal condition = fn.input("Breakpoint condition: ")
\tif condition == nil or condition == "" then
\t\treturn
\tend
\tdebug.toggle_breakpoint(condition)
\trefresh_all_breakpoint_signs()
end

function M.set_logpoint()
\tdefine_signs()
\tlocal message = fn.input("Log message: ")
\tif message == nil or message == "" then
\t\treturn
\tend
\tdebug.toggle_breakpoint(nil, nil, message)
\trefresh_all_breakpoint_signs()
end

function M.clear_breakpoints()
\tif debug.clear_breakpoints then
\t\tdebug.clear_breakpoints()
\tend
\trefresh_all_breakpoint_signs()
end

function M.continue()
\tdebug.continue()
end

function M.pause()
\tif debug.pause then
\t\tdebug.pause()
\tend
end

function M.terminate()
\tclear_stopped_signs()
\tif debug.terminate then
\t\tdebug.terminate()
\tend
end

function M.restart()
\tif debug.restart then
\t\tdebug.restart()
\tend
end

function M.step_over()
\tdebug.step_over()
end

function M.step_into()
\tdebug.step_into()
end

function M.step_out()
\tdebug.step_out()
end

function M.run_last()
\tif debug.run_last then
\t\tdebug.run_last()
\tend
end

function M.repl()
\tif debug.repl then
\t\tdebug.repl.open()
\tend
end

function M.eval()
\tif debug.eval then
\t\tdebug.eval()
\tend
end

function M.hover()
\tif debug.hover then
\t\tdebug.hover()
\tend
end

function M.scopes()
\tif debug.widgets and debug.widgets.scopes then
\t\tdebug.widgets.scopes()
\tend
end

function M.frames()
\tif debug.widgets and debug.widgets.frames then
\t\tdebug.widgets.frames()
\tend
end

function M.threads()
\tif debug.widgets and debug.widgets.threads then
\t\tdebug.widgets.threads()
\tend
end

function M.launch_lldb()
\tstart("lldb", {
\t\trequest = "launch",
\t\tname = "Launch current file (lldb)",
\t\tprogram = prompt_program(),
\t\targs = prompt_args(),
\t\tcwd = prompt_cwd(),
\t\tstopOnEntry = false,
\t})
end

function M.launch_gdb()
\tstart("gdb", {
\t\trequest = "launch",
\t\tname = "Launch current file (gdb)",
\t\tprogram = prompt_program(),
\t\targs = prompt_args(),
\t\tcwd = prompt_cwd(),
\t\tstopAtBeginningOfMainSubprogram = false,
\t})
end

function M.attach_node()
\tstart("pwa-node", {
\t\trequest = "attach",
\t\tname = "Attach to node process",
\t\tprocessId = fn.input("Process ID: "),
\t\tcwd = prompt_cwd(),
\t})
end

function M.setup()
\tdefine_signs()

\tapi.nvim_create_user_command("DapContinue", M.continue, {})
\tapi.nvim_create_user_command("DapPause", M.pause, {})
\tapi.nvim_create_user_command("DapTerminate", M.terminate, {})
\tapi.nvim_create_user_command("DapRestart", M.restart, {})
\tapi.nvim_create_user_command("DapRunLast", M.run_last, {})

\tapi.nvim_create_user_command("DapToggleBreakpoint", M.toggle_breakpoint, {})
\tapi.nvim_create_user_command("DapConditionalBreakpoint", M.set_conditional_breakpoint, {})
\tapi.nvim_create_user_command("DapLogPoint", M.set_logpoint, {})
\tapi.nvim_create_user_command("DapClearBreakpoints", M.clear_breakpoints, {})

\tapi.nvim_create_user_command("DapStepOver", M.step_over, {})
\tapi.nvim_create_user_command("DapStepInto", M.step_into, {})
\tapi.nvim_create_user_command("DapStepOut", M.step_out, {})

\tapi.nvim_create_user_command("DapRepl", M.repl, {})
\tapi.nvim_create_user_command("DapEval", M.eval, { range = true })
\tapi.nvim_create_user_command("DapHover", M.hover, {})
\tapi.nvim_create_user_command("DapScopes", M.scopes, {})
\tapi.nvim_create_user_command("DapFrames", M.frames, {})
\tapi.nvim_create_user_command("DapThreads", M.threads, {})

\tapi.nvim_create_user_command("DapLaunchLLDB", M.launch_lldb, {})
\tapi.nvim_create_user_command("DapLaunchGDB", M.launch_gdb, {})
\tapi.nvim_create_user_command("DapAttachNode", M.attach_node, {})

\tvim.keymap.set("n", "<F5>", M.continue, { desc = "DAP continue" })
\tvim.keymap.set("n", "<F6>", M.pause, { desc = "DAP pause" })
\tvim.keymap.set("n", "<F9>", M.toggle_breakpoint, { desc = "DAP toggle breakpoint" })
\tvim.keymap.set("n", "<F10>", M.step_over, { desc = "DAP step over" })
\tvim.keymap.set("n", "<F11>", M.step_into, { desc = "DAP step into" })
\tvim.keymap.set("n", "<S-F11>", M.step_out, { desc = "DAP step out" })
\tvim.keymap.set("n", "<leader>dc", M.set_conditional_breakpoint, { desc = "DAP conditional breakpoint" })
\tvim.keymap.set("n", "<leader>dl", M.set_logpoint, { desc = "DAP log point" })
\tvim.keymap.set("n", "<leader>dr", M.repl, { desc = "DAP REPL" })
\tvim.keymap.set({ "n", "v" }, "<leader>de", M.eval, { desc = "DAP eval" })
\tvim.keymap.set("n", "<leader>dh", M.hover, { desc = "DAP hover" })
\tvim.keymap.set("n", "<leader>ds", M.scopes, { desc = "DAP scopes" })
\tvim.keymap.set("n", "<leader>df", M.frames, { desc = "DAP frames" })
\tvim.keymap.set("n", "<leader>dt", M.threads, { desc = "DAP threads" })

\tlocal group = api.nvim_create_augroup("qompass.dap", { clear = true })

\tif debug.listeners then
\t\tdebug.listeners.after.event_initialized["qompass-dap"] = function()
\t\t\trefresh_all_breakpoint_signs()
\t\tend

\t\tdebug.listeners.after.event_stopped["qompass-dap"] = function(session)
\t\t\tplace_stopped_sign(session)
\t\tend

\t\tdebug.listeners.before.event_continued["qompass-dap"] = function()
\t\t\tclear_stopped_signs()
\t\tend

\t\tdebug.listeners.before.event_terminated["qompass-dap"] = function()
\t\t\tclear_stopped_signs()
\t\tend

\t\tdebug.listeners.before.event_exited["qompass-dap"] = function()
\t\t\tclear_stopped_signs()
\t\tend
\tend

\tapi.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
\t\tgroup = group,
\t\tdesc = "Refresh DAP breakpoint signs",
\t\tcallback = function(event)
\t\t\trefresh_breakpoint_signs(event.buf)
\t\tend,
\t})
end

return M