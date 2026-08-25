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
local debug = vim.debug
local fn = vim.fn
local M = {}
pcall(function()
	require('dap.android').setup()
end)
pcall(function()
	require('dap.bash').setup()
end)
pcall(function()
	require('dap.lua').setup()
end)
pcall(function()
	require('dap.python').setup()
end)
pcall(function()
	require('dap.rust').setup()
end)
pcall(function()
	require('dap.scala').setup()
end)
pcall(function()
	require('dap.zig').setup()
end)
---@type table<string, integer>
local namespaces = {}
---@param name string
---@return integer
local function namespace(name)
	local existing = namespaces[name]
	if existing ~= nil then
		return existing
	end
	local ns = api.nvim_create_namespace('qompass.dap.' .. name)
	namespaces[name] = ns
	return ns
end

---@param bufnr integer
---@param lnum integer
---@param opts? { condition?: string, log_message?: string }
local function place_breakpoint_sign(bufnr, lnum, opts)
	local sign_text = '●'
	local sign_hl_group = 'DiagnosticSignError'

	if opts and opts.condition and opts.condition ~= '' then
		sign_text = '◆'
		sign_hl_group = 'DiagnosticSignWarn'
	elseif opts and opts.log_message and opts.log_message ~= '' then
		sign_text = '▶'
		sign_hl_group = 'DiagnosticSignInfo'
	end

	api.nvim_buf_set_extmark(bufnr, namespace('breakpoints'), lnum - 1, 0, {
		sign_text = sign_text,
		sign_hl_group = sign_hl_group,
		priority = 60,
	})
end

---@param bufnr integer
local function refresh_breakpoint_signs(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return
	end

	api.nvim_buf_clear_namespace(bufnr, namespace('breakpoints'), 0, -1)

	local breakpoints = debug.get_breakpoints and debug.get_breakpoints(bufnr) or nil
	if type(breakpoints) ~= 'table' then
		return
	end

	for _, bp in ipairs(breakpoints) do
		local raw_lnum = bp.line or bp.lnum or bp[1]

		if type(raw_lnum) == 'number' and raw_lnum > 0 and raw_lnum % 1 == 0 then
			local lnum = math.floor(raw_lnum)
			place_breakpoint_sign(bufnr, lnum, {
				condition = bp.condition,
				log_message = bp.logMessage or bp.log_message,
			})
		end
	end
end

local function refresh_all_breakpoint_signs()
	for _, bufnr in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
			refresh_breakpoint_signs(bufnr)
		end
	end
end

---@type integer?
local stopped_bufnr

local function clear_stopped_signs()
	if stopped_bufnr and api.nvim_buf_is_valid(stopped_bufnr) then
		api.nvim_buf_clear_namespace(stopped_bufnr, namespace('stopped'), 0, -1)
	end
	stopped_bufnr = nil
end
---@param session any
local function place_stopped_sign(session)
	clear_stopped_signs()
	if not session or not session.current_frame then
		return
	end
	local frame = session.current_frame
	local source = frame.source or {}
	local path = source.path
	if type(path) ~= 'string' or path == '' then
		return
	end
	local raw_bufnr = fn.bufadd(path)
	if type(raw_bufnr) ~= 'number' or raw_bufnr < 1 then
		return
	end
	local bufnr = math.floor(raw_bufnr)
	fn.bufload(bufnr)
	local raw_lnum = frame.line
	if type(raw_lnum) ~= 'number' or raw_lnum < 1 or raw_lnum % 1 ~= 0 then
		return
	end
	local lnum = math.floor(raw_lnum)
	api.nvim_buf_set_extmark(bufnr, namespace('stopped'), lnum - 1, 0, {
		sign_text = '→',
		sign_hl_group = 'DiagnosticSignHint',
		line_hl_group = 'Visual',
		number_hl_group = 'DiagnosticSignHint',
		priority = 100,
	})
	stopped_bufnr = bufnr
end

local function prompt_program()
	return fn.input('Program: ', fn.getcwd() .. '/', 'file')
end

local function prompt_args()
	local line = fn.input('Args: ')
	if line == nil or line == '' then
		return {}
	end
	return vim.split(line, '%s+', { trimempty = true })
end
local function prompt_cwd()
	local cwd = fn.input('Cwd: ', fn.getcwd(), 'dir')
	if cwd == nil or cwd == '' then
		return fn.getcwd()
	end
	return cwd
end

---@param adapter string
---@param config table
local function start(adapter, config)
	config.type = adapter
	debug.start(config)
end
function M.toggle_breakpoint()
	debug.toggle_breakpoint()
	refresh_all_breakpoint_signs()
end

function M.set_conditional_breakpoint()
	local condition = fn.input('Breakpoint condition: ')
	if condition == nil or condition == '' then
		return
	end
	debug.toggle_breakpoint(condition)
	refresh_all_breakpoint_signs()
end

function M.set_logpoint()
	local message = fn.input('Log message: ')
	if message == nil or message == '' then
		return
	end
	debug.toggle_breakpoint(nil, nil, message)
	refresh_all_breakpoint_signs()
end
function M.clear_breakpoints()
	if debug.clear_breakpoints then
		debug.clear_breakpoints()
	end
	refresh_all_breakpoint_signs()
end
function M.continue()
	debug.continue()
end
function M.pause()
	if debug.pause then
		debug.pause()
	end
end
function M.terminate()
	clear_stopped_signs()
	if debug.terminate then
		debug.terminate()
	end
end
function M.restart()
	if debug.restart then
		debug.restart()
	end
end
function M.step_over()
	debug.step_over()
end

function M.step_into()
	debug.step_into()
end
function M.step_out()
	debug.step_out()
end
function M.run_last()
	if debug.run_last then
		debug.run_last()
	end
end
function M.repl()
	if debug.repl then
		debug.repl.open()
	end
end
function M.eval()
	if debug.eval then
		debug.eval()
	end
end
function M.hover()
	if debug.hover then
		debug.hover()
	end
end
function M.scopes()
	if debug.widgets and debug.widgets.scopes then
		debug.widgets.scopes()
	end
end
function M.frames()
	if debug.widgets and debug.widgets.frames then
		debug.widgets.frames()
	end
end
function M.threads()
	if debug.widgets and debug.widgets.threads then
		debug.widgets.threads()
	end
end
function M.launch_lldb()
	start('lldb', {
		request = 'launch',
		name = 'Launch current file (lldb)',
		program = prompt_program(),
		args = prompt_args(),
		cwd = prompt_cwd(),
		stopOnEntry = false,
	})
end

function M.launch_gdb()
	start('gdb', {
		request = 'launch',
		name = 'Launch current file (gdb)',
		program = prompt_program(),
		args = prompt_args(),
		cwd = prompt_cwd(),
		stopAtBeginningOfMainSubprogram = false,
	})
end

function M.attach_node()
	start('pwa-node', {
		request = 'attach',
		name = 'Attach to node process',
		processId = fn.input('Process ID: '),
		cwd = prompt_cwd(),
	})
end

function M.setup()
	namespace('breakpoints')
	namespace('stopped')

	api.nvim_create_user_command('DapContinue', M.continue, {})
	api.nvim_create_user_command('DapPause', M.pause, {})
	api.nvim_create_user_command('DapTerminate', M.terminate, {})
	api.nvim_create_user_command('DapRestart', M.restart, {})
	api.nvim_create_user_command('DapRunLast', M.run_last, {})

	api.nvim_create_user_command('DapToggleBreakpoint', M.toggle_breakpoint, {})
	api.nvim_create_user_command('DapConditionalBreakpoint', M.set_conditional_breakpoint, {})
	api.nvim_create_user_command('DapLogPoint', M.set_logpoint, {})
	api.nvim_create_user_command('DapClearBreakpoints', M.clear_breakpoints, {})

	api.nvim_create_user_command('DapStepOver', M.step_over, {})
	api.nvim_create_user_command('DapStepInto', M.step_into, {})
	api.nvim_create_user_command('DapStepOut', M.step_out, {})

	api.nvim_create_user_command('DapRepl', M.repl, {})
	api.nvim_create_user_command('DapEval', M.eval, { range = true })
	api.nvim_create_user_command('DapHover', M.hover, {})
	api.nvim_create_user_command('DapScopes', M.scopes, {})
	api.nvim_create_user_command('DapFrames', M.frames, {})
	api.nvim_create_user_command('DapThreads', M.threads, {})

	api.nvim_create_user_command('DapLaunchLLDB', M.launch_lldb, {})
	api.nvim_create_user_command('DapLaunchGDB', M.launch_gdb, {})
	api.nvim_create_user_command('DapAttachNode', M.attach_node, {})

	vim.keymap.set('n', '<F5>', M.continue, { desc = 'DAP continue' })
	vim.keymap.set('n', '<F6>', M.pause, { desc = 'DAP pause' })
	vim.keymap.set('n', '<F9>', M.toggle_breakpoint, { desc = 'DAP toggle breakpoint' })
	vim.keymap.set('n', '<F10>', M.step_over, { desc = 'DAP step over' })
	vim.keymap.set('n', '<F11>', M.step_into, { desc = 'DAP step into' })
	vim.keymap.set('n', '<S-F11>', M.step_out, { desc = 'DAP step out' })
	vim.keymap.set('n', '<leader>dc', M.set_conditional_breakpoint, { desc = 'DAP conditional breakpoint' })
	vim.keymap.set('n', '<leader>dl', M.set_logpoint, { desc = 'DAP log point' })
	vim.keymap.set('n', '<leader>dr', M.repl, { desc = 'DAP REPL' })
	vim.keymap.set({ 'n', 'v' }, '<leader>de', M.eval, { desc = 'DAP eval' })
	vim.keymap.set('n', '<leader>dh', M.hover, { desc = 'DAP hover' })
	vim.keymap.set('n', '<leader>ds', M.scopes, { desc = 'DAP scopes' })
	vim.keymap.set('n', '<leader>df', M.frames, { desc = 'DAP frames' })
	vim.keymap.set('n', '<leader>dt', M.threads, { desc = 'DAP threads' })
	local group = api.nvim_create_augroup('qompass.dap', { clear = true })
	if debug.listeners then
		debug.listeners.after.event_initialized['qompass-dap'] = function()
			refresh_all_breakpoint_signs()
		end
		debug.listeners.after.event_stopped['qompass-dap'] = function(session)
			place_stopped_sign(session)
		end
		debug.listeners.before.event_continued['qompass-dap'] = function()
			clear_stopped_signs()
		end
		debug.listeners.before.event_terminated['qompass-dap'] = function()
			clear_stopped_signs()
		end
		debug.listeners.before.event_exited['qompass-dap'] = function()
			clear_stopped_signs()
		end
	end
	api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
		group = group,
		desc = 'Refresh DAP breakpoint signs',
		callback = function(event)
			refresh_breakpoint_signs(event.buf)
		end,
	})
end

return M
