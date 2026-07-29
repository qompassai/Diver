-- #################################################################
-- /qompassai/lua/utils/bsp/init.lua
-- Qompass AI Init
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at:
--   http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- #################################################################
local api = vim.api
local cargo = require('bsp.cargo')
local gradle = require('bsp.gradle')
--[[
--mkdir -p "$HOME/.local/src"

git clone \
	--depth 1 \
	https://github.com/cargo-bsp/cargo-bsp.git \
	"$HOME/.local/src/cargo-bsp"

cd "$HOME/.local/src/cargo-bsp"

RUSTUP_TOOLCHAIN=nightly \
	./install.sh "$(realpath /path/to/your/rust/project)"
	jq . /path/to/your/rust/project/.bsp/cargo-bsp.json
	:BspInfo
:BspTargets
:BspCompile
:BspReload
:BspRestart
:BspStop
--]]
local M = {}

---@class QompassBspConfig
---@field auto_start boolean
---@field client_name string
---@field client_version string
---@field notify boolean
---@field server_name string|nil
---@field trace boolean

---@class QompassBspConfigOpts
---@field auto_start? boolean
---@field client_name? string
---@field client_version? string
---@field notify? boolean
---@field server_name? string|nil
---@field trace? boolean

---@class QompassBspRpc
---@field is_closing fun(): boolean
---@field notify fun(method: string, params: table|nil): boolean
---@field request fun(method: string, params: table|nil, callback: fun(err: table|nil, result: any, request_id: integer)): boolean, integer|nil
---@field terminate fun()

---@param client vim.lsp.rpc.Client
---@return QompassBspRpc
local function wrap_rpc(client)
	---@type table
	local raw_client = client

	return {
		is_closing = function()
			return raw_client.is_closing()
		end,
		notify = function(method, params)
			return raw_client:notify(method, params)
		end,
		request = function(method, params, callback)
			return raw_client:request(method, params, callback)
		end,
		terminate = function()
			raw_client.terminate()
		end,
	}
end

---@class QompassBspTargetIdentifier
---@field uri string

---@class QompassBspTarget
---@field id QompassBspTargetIdentifier
---@field displayName? string
---@field capabilities? table
---@field languageIds? string[]

---@class QompassBspSession
---@field connection QompassBspConnection
---@field initialized boolean
---@field root string
---@field rpc QompassBspRpc
---@field server_info table|nil
---@field targets QompassBspTarget[]

local neovim_version = vim.version()
local defaults = {
	auto_start = true,
	client_name = 'Neovim',
	client_version = string.format('%d.%d.%d', neovim_version.major, neovim_version.minor, neovim_version.patch),
	notify = true,
	server_name = 'cargo-bsp',
	trace = false,
}

---@type QompassBspConfig
M.config = vim.deepcopy(defaults)

M.state = {
	---@type table<string, QompassBspSession>
	sessions = {},
	---@type table<string, integer>
	diagnostic_namespaces = {},
}

---@param message string
---@param level? integer
local function notify(message, level)
	if not M.config.notify then
		return
	end

	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'BSP',
	})
end

---@param root? string
---@return string|nil
local function resolve_root(root)
	if root and root ~= '' then
		return vim.fs.normalize(root)
	end

	return cargo.root()
end

---@param root? string
---@return QompassBspSession|nil
local function get_session(root)
	root = resolve_root(root)
	return root and M.state.sessions[root] or nil
end

---@param err table|string|nil
---@return string
local function error_message(err)
	if type(err) == 'table' then
		if type(err.message) == 'string' then
			return err.message
		end
		return vim.inspect(err)
	end

	return tostring(err or 'unknown BSP error')
end

---@param target_uri string
---@return integer
local function diagnostic_namespace(target_uri)
	local namespace = M.state.diagnostic_namespaces[target_uri]
	if namespace then
		return namespace
	end

	namespace = api.nvim_create_namespace('qompass.bsp.' .. target_uri)
	M.state.diagnostic_namespaces[target_uri] = namespace
	return namespace
end

local severity = {
	[1] = vim.diagnostic.severity.ERROR,
	[2] = vim.diagnostic.severity.WARN,
	[3] = vim.diagnostic.severity.INFO,
	[4] = vim.diagnostic.severity.HINT,
}

---@param bufnr integer
---@param item table
---@return vim.Diagnostic|nil
local function convert_diagnostic(bufnr, item)
	if type(item) ~= 'table' or type(item.range) ~= 'table' then
		return nil
	end

	local start = item.range.start
	local finish = item.range['end']
	if type(start) ~= 'table' or type(finish) ~= 'table' or type(item.message) ~= 'string' then
		return nil
	end
	if
		type(start.line) ~= 'number'
		or type(start.character) ~= 'number'
		or type(finish.line) ~= 'number'
		or type(finish.character) ~= 'number'
	then
		return nil
	end

	---@type vim.Diagnostic
	local diagnostic = {
		bufnr = bufnr,
		code = item.code,
		col = math.floor(start.character),
		end_col = math.floor(finish.character),
		end_lnum = math.floor(finish.line),
		lnum = math.floor(start.line),
		message = item.message,
		severity = severity[item.severity] or vim.diagnostic.severity.ERROR,
		source = item.source or 'BSP',
		user_data = {
			bsp = item,
		},
	}

	return diagnostic
end

---@param params table
local function publish_diagnostics(params)
	local document = params.textDocument
	local target = params.buildTarget
	if type(document) ~= 'table' or type(document.uri) ~= 'string' then
		return
	end
	if type(target) ~= 'table' or type(target.uri) ~= 'string' then
		return
	end

	local ok_name, filename = pcall(vim.uri_to_fname, document.uri)
	if not ok_name or type(filename) ~= 'string' or filename == '' then
		return
	end

	local bufnr = vim.fn.bufadd(filename)
	local namespace = diagnostic_namespace(target.uri)
	---@type vim.Diagnostic[]
	local diagnostics = {}

	if params.reset ~= true then
		diagnostics = vim.diagnostic.get(bufnr, {
			namespace = namespace,
		})
	end

	for _, item in ipairs(params.diagnostics or {}) do
		local diagnostic = convert_diagnostic(bufnr, item)
		if diagnostic then
			diagnostics[#diagnostics + 1] = diagnostic
		end
	end

	vim.diagnostic.set(namespace, bufnr, diagnostics, {
		underline = true,
		virtual_text = false,
	})
end

local message_levels = {
	[1] = vim.log.levels.ERROR,
	[2] = vim.log.levels.WARN,
	[3] = vim.log.levels.INFO,
	[4] = vim.log.levels.DEBUG,
}

---@param method string
---@param params table
local function dispatch_notification(method, params)
	if M.config.trace then
		notify(method .. ': ' .. vim.inspect(params), vim.log.levels.DEBUG)
	end

	if method == 'build/publishDiagnostics' then
		publish_diagnostics(params)
	elseif method == 'build/showMessage' or method == 'build/logMessage' then
		if type(params.message) == 'string' then
			notify(params.message, message_levels[params.type])
		end
	elseif method == 'build/taskStart' then
		if type(params.message) == 'string' then
			notify(params.message)
		end
	elseif method == 'build/taskFinish' then
		if type(params.message) == 'string' then
			local level = params.status == 2 and vim.log.levels.ERROR or vim.log.levels.INFO
			notify(params.message, level)
		end
	elseif method == 'run/printStdout' or method == 'run/printStderr' then
		if type(params.message) == 'string' then
			api.nvim_echo({
				{
					params.message,
				},
			}, false, {})
		end
	end
end

---@param root string
---@param method string
---@param params table|nil
---@param callback fun(err: table|nil, result: any)
---@return boolean
local function request(root, method, params, callback)
	local session = M.state.sessions[root]
	if not session or not session.initialized or session.rpc.is_closing() then
		notify('No initialized BSP session exists for ' .. root, vim.log.levels.ERROR)
		return false
	end

	local sent = session.rpc.request(method, params, function(err, result)
		vim.schedule(function()
			callback(err, result)
		end)
	end)
	if not sent then
		notify('Failed to send BSP request: ' .. method, vim.log.levels.ERROR)
	end

	return sent
end

---@param root string
---@param callback? fun(targets: QompassBspTarget[])
local function refresh_targets(root, callback)
	request(root, 'workspace/buildTargets', nil, function(err, result)
		if err then
			notify('Target discovery failed: ' .. error_message(err), vim.log.levels.ERROR)
			return
		end
		if type(result) ~= 'table' or type(result.targets) ~= 'table' then
			notify('The BSP server returned an invalid target list', vim.log.levels.ERROR)
			return
		end

		local session = M.state.sessions[root]
		if not session then
			return
		end

		session.targets = result.targets
		if callback then
			callback(session.targets)
		end
	end)
end

---@param bufnr? integer
function M.start(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local root = cargo.root(bufnr)
	if not root then
		notify('No Cargo/BSP project root was found', vim.log.levels.WARN)
		return
	end

	local existing = M.state.sessions[root]
	if existing and not existing.rpc.is_closing() then
		notify('BSP is already running for ' .. root)
		return
	end

	local connection, connection_error = cargo.connection(root, M.config.server_name)
	if not connection then
		notify(connection_error or 'No BSP connection is available', vim.log.levels.ERROR)
		return
	end

	local executable, executable_error = cargo.executable(connection)
	if not executable then
		notify(executable_error or 'The BSP server is not executable', vim.log.levels.ERROR)
		return
	end

	local session = {
		connection = connection,
		initialized = false,
		root = root,
		server_info = nil,
		targets = {},
	}

	local dispatchers = {
		notification = function(method, params)
			dispatch_notification(method, params or {})
		end,
		on_error = function(code, err)
			notify(string.format('RPC error %s: %s', tostring(code), tostring(err)), vim.log.levels.ERROR)
		end,
		on_exit = function(code, signal)
			vim.schedule(function()
				if M.state.sessions[root] == session then
					M.state.sessions[root] = nil
				end
				if code ~= 0 then
					notify(
						string.format('BSP server exited with code %s (signal %s)', tostring(code), tostring(signal)),
						vim.log.levels.ERROR
					)
				end
			end)
		end,
		server_request = function(method)
			return nil, {
				code = -32601,
				message = 'Unsupported BSP client request: ' .. method,
			}
		end,
	}

	---@type vim.lsp.rpc.Client|nil
	local rpc_client
	local ok_start, start_error = pcall(function()
		rpc_client = vim.lsp.rpc.start(connection.argv, dispatchers, {
			cwd = root,
			detached = false,
		})
	end)
	if not ok_start then
		notify('Failed to start BSP server: ' .. tostring(start_error), vim.log.levels.ERROR)
		return
	end
	if not rpc_client then
		notify('Failed to start BSP server: no RPC client was returned', vim.log.levels.ERROR)
		return
	end

	local rpc = wrap_rpc(rpc_client)
	session.rpc = rpc
	---@cast session QompassBspSession
	M.state.sessions[root] = session

	local sent = rpc.request('build/initialize', {
		bspVersion = connection.bspVersion,
		capabilities = {
			languageIds = connection.languages,
		},
		displayName = M.config.client_name,
		rootUri = vim.uri_from_fname(root),
		version = M.config.client_version,
	}, function(err, result)
		vim.schedule(function()
			if M.state.sessions[root] ~= session then
				return
			end
			if err then
				notify('BSP initialization failed: ' .. error_message(err), vim.log.levels.ERROR)
				session.rpc.terminate()
				M.state.sessions[root] = nil
				return
			end
			if type(result) ~= 'table' then
				notify('BSP initialization returned no server information', vim.log.levels.ERROR)
				session.rpc.terminate()
				M.state.sessions[root] = nil
				return
			end

			session.initialized = true
			session.server_info = result
			session.rpc.notify('build/initialized', {})
			notify(string.format('Connected to %s %s', result.displayName or connection.name, result.version or ''))
			refresh_targets(root)
		end)
	end)

	if not sent then
		session.rpc.terminate()
		M.state.sessions[root] = nil
		notify('Could not send build/initialize', vim.log.levels.ERROR)
	end
end

---@param root? string
function M.compile(root)
	root = resolve_root(root)
	if not root then
		notify('No Cargo/BSP project root was found', vim.log.levels.ERROR)
		return
	end

	local session = M.state.sessions[root]
	if not session or not session.initialized then
		notify('Start BSP first with :BspStart', vim.log.levels.ERROR)
		return
	end

	---@param targets QompassBspTarget[]
	local function compile_targets(targets)
		local identifiers = {}
		for _, target in ipairs(targets) do
			if target.id and type(target.id.uri) == 'string' then
				identifiers[#identifiers + 1] = target.id
			end
		end
		if #identifiers == 0 then
			notify('The BSP server reported no compilable targets', vim.log.levels.WARN)
			return
		end

		request(root, 'buildTarget/compile', {
			originId = 'neovim-' .. tostring(vim.uv.hrtime()),
			targets = identifiers,
		}, function(err, result)
			if err then
				notify('BSP compilation failed: ' .. error_message(err), vim.log.levels.ERROR)
				return
			end

			local status = type(result) == 'table' and result.statusCode or nil
			if status == 1 then
				notify('BSP compilation completed successfully')
			elseif status == 3 then
				notify('BSP compilation was cancelled', vim.log.levels.WARN)
			else
				notify('BSP compilation failed', vim.log.levels.ERROR)
			end
		end)
	end

	if #session.targets == 0 then
		refresh_targets(root, compile_targets)
	else
		compile_targets(session.targets)
	end
end

---@param root? string
function M.reload(root)
	root = resolve_root(root)
	if not root then
		notify('No Cargo/BSP project root was found', vim.log.levels.ERROR)
		return
	end

	request(root, 'workspace/reload', nil, function(err)
		if err then
			notify('BSP reload failed: ' .. error_message(err), vim.log.levels.ERROR)
			return
		end
		refresh_targets(root, function()
			notify('BSP workspace reloaded')
		end)
	end)
end

---@param root? string
function M.targets(root)
	root = resolve_root(root)
	if not root then
		notify('No Cargo/BSP project root was found', vim.log.levels.ERROR)
		return
	end

	local session = M.state.sessions[root]
	if not session or not session.initialized then
		notify('Start BSP first with :BspStart', vim.log.levels.ERROR)
		return
	end

	local function show()
		local lines = {}
		for index, target in ipairs(session.targets) do
			lines[#lines + 1] = string.format(
				'%d. %s [%s]',
				index,
				target.displayName or target.id.uri,
				table.concat(target.languageIds or {}, ', ')
			)
		end
		notify(#lines > 0 and table.concat(lines, '\n') or 'No BSP targets were reported')
	end

	if #session.targets == 0 then
		refresh_targets(root, show)
	else
		show()
	end
end

---@param root? string
function M.info(root)
	local session = get_session(root)
	if not session then
		notify('No BSP session is running')
		return
	end

	notify(vim.inspect({
		connection = {
			argv = session.connection.argv,
			bspVersion = session.connection.bspVersion,
			languages = session.connection.languages,
			name = session.connection.name,
			path = session.connection.path,
			version = session.connection.version,
		},
		initialized = session.initialized,
		root = session.root,
		server = session.server_info,
		target_count = #session.targets,
	}))
end

---@param root? string
function M.stop(root)
	root = resolve_root(root)
	if not root then
		notify('No Cargo/BSP project root was found', vim.log.levels.ERROR)
		return
	end

	local session = M.state.sessions[root]
	if not session then
		notify('No BSP session is running for ' .. root)
		return
	end

	if not session.initialized then
		session.rpc.terminate()
		M.state.sessions[root] = nil
		return
	end

	local sent = session.rpc.request('build/shutdown', nil, function()
		vim.schedule(function()
			if not session.rpc.is_closing() then
				session.rpc.notify('build/exit', {})
			end
			M.state.sessions[root] = nil
		end)
	end)
	if not sent then
		session.rpc.terminate()
		M.state.sessions[root] = nil
	end
end

---@param bufnr? integer
function M.restart(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local root = cargo.root(bufnr)
	if not root then
		notify('No Cargo/BSP project root was found', vim.log.levels.ERROR)
		return
	end

	local session = M.state.sessions[root]
	if not session then
		M.start(bufnr)
		return
	end

	if session.initialized then
		session.rpc.request('build/shutdown', nil, function()
			vim.schedule(function()
				session.rpc.notify('build/exit', {})
				M.state.sessions[root] = nil
				M.start(bufnr)
			end)
		end)
	else
		session.rpc.terminate()
		M.state.sessions[root] = nil
		M.start(bufnr)
	end
end

local function create_autocmds()
	local group = api.nvim_create_augroup('QompassNativeBsp', {
		clear = true,
	})

	api.nvim_create_autocmd('FileType', {
		callback = function(args)
			if M.config.auto_start then
				M.start(args.buf)
			end
		end,
		group = group,
		pattern = 'rust',
	})
	api.nvim_create_autocmd('VimLeavePre', {
		callback = function()
			for _, session in pairs(M.state.sessions) do
				if session.initialized and not session.rpc.is_closing() then
					session.rpc.notify('build/exit', {})
				end
			end
		end,
		group = group,
	})
end

---@param opts? QompassBspConfigOpts
---@return table
function M.setup(opts)
	M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
	require('utils.bsp.commands').setup({
		compile = function(root)
			M.compile(root)
		end,
		info = function(root)
			M.info(root)
		end,
		reload = function(root)
			M.reload(root)
		end,
		restart = function(bufnr)
			M.restart(bufnr)
		end,
		start = function(bufnr)
			M.start(bufnr)
		end,
		stop = function(root)
			M.stop(root)
		end,
		targets = function(root)
			M.targets(root)
		end,
	})
	create_autocmds()
	return M
end

return M
