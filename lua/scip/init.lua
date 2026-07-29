-- #################################################################
-- /qompassai/lua/scip/init.lua
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
local fn = vim.fn
local M = {}
---@class QompassScipContext
---@field bufnr integer
---@field index_file string
---@field name string
---@field root string

---@class QompassScipIndexer
---@field command string|fun(context: QompassScipContext): string
---@field args string[]|fun(context: QompassScipContext): string[]
---@field filetypes table<string, boolean>
---@field markers string[]
---@field enabled? boolean

---@class QompassScipConfig
---@field index_file string
---@field lint_after_index boolean
---@field notify boolean
---@field root_markers string[]
---@field indexer_order string[]
---@field indexers table<string, QompassScipIndexer>

---@class QompassScipConfigOpts
---@field index_file? string
---@field lint_after_index? boolean
---@field notify? boolean
---@field root_markers? string[]
---@field indexer_order? string[]
---@field indexers? table<string, QompassScipIndexer>
local function path_exists(path)
	local stat = vim.uv.fs_stat(path)
	return stat ~= nil
end

---@param context QompassScipContext
---@return string
local function php_command(context)
	local local_command = vim.fs.joinpath(context.root, 'vendor', 'bin', 'scip-php')
	if path_exists(local_command) then
		return local_command
	end

	return 'scip-php'
end

---@param context QompassScipContext
---@return string[]
local function ruby_args(context)
	if path_exists(vim.fs.joinpath(context.root, 'sorbet', 'config')) then
		return {}
	end

	return {
		'.',
	}
end

---@param root string
---@return string[]
local function typescript_args(root)
	if path_exists(vim.fs.joinpath(root, 'tsconfig.json')) or path_exists(vim.fs.joinpath(root, 'jsconfig.json')) then
		return {
			'index',
		}
	end

	return {
		'index',
		'--infer-tsconfig',
	}
end

---@param root string
---@return string
local function compilation_database(root)
	local candidates = {
		vim.fs.joinpath(root, 'compile_commands.json'),
		vim.fs.joinpath(root, 'build', 'compile_commands.json'),
		vim.fs.joinpath(root, 'cmake-build-debug', 'compile_commands.json'),
		vim.fs.joinpath(root, 'cmake-build-release', 'compile_commands.json'),
	}

	for _, path in ipairs(candidates) do
		if path_exists(path) then
			return path
		end
	end

	error(
		'No compile_commands.json was found. Configure CMake with '
			.. '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON, then build the project.'
	)
end

local defaults = {
	index_file = 'index.scip',
	lint_after_index = true,
	notify = true,
	root_markers = {
		'.git',
		'.hg',
	},
	indexer_order = {
		'clang',
		'dart',
		'dotnet',
		'go',
		'java',
		'php',
		'python',
		'ruby',
		'rust',
		'typescript',
	},
	indexers = {
		clang = {
			command = 'scip-clang',
			args = function(context)
				return {
					'--compdb-path=' .. compilation_database(context.root),
				}
			end,
			filetypes = {
				c = true,
				cpp = true,
				cuda = true,
				objc = true,
				objcpp = true,
			},
			markers = {
				'.git',
				'CMakeLists.txt',
				'compile_commands.json',
			},
		},
		dart = {
			command = 'dart',
			args = {
				'pub',
				'global',
				'run',
				'scip_dart',
				'.',
			},
			filetypes = {
				dart = true,
			},
			markers = {
				'.git',
				'pubspec.yaml',
			},
		},
		dotnet = {
			command = 'scip-dotnet',
			args = {
				'index',
			},
			filetypes = {
				cs = true,
				vb = true,
			},
			markers = {
				'.git',
				'Directory.Build.props',
				'Directory.Build.targets',
				'global.json',
			},
		},
		go = {
			command = 'scip-go',
			args = {},
			filetypes = {
				go = true,
			},
			markers = {
				'.git',
				'go.mod',
				'go.work',
			},
		},
		java = {
			command = 'scip-java',
			args = {
				'index',
			},
			filetypes = {
				java = true,
				kotlin = true,
			},
			markers = {
				'.git',
				'build.gradle',
				'build.gradle.kts',
				'pom.xml',
				'settings.gradle',
				'settings.gradle.kts',
			},
		},
		php = {
			command = php_command,
			args = {},
			filetypes = {
				php = true,
			},
			markers = {
				'.git',
				'composer.json',
				'composer.lock',
			},
		},
		python = {
			command = 'scip-python',
			args = {
				'index',
				'.',
			},
			filetypes = {
				python = true,
			},
			markers = {
				'.git',
				'pyproject.toml',
				'requirements.txt',
				'setup.cfg',
				'setup.py',
			},
		},
		ruby = {
			command = 'scip-ruby',
			args = ruby_args,
			filetypes = {
				ruby = true,
			},
			markers = {
				'.git',
				'Gemfile',
				'Rakefile',
			},
		},
		rust = {
			command = 'rust-analyzer',
			args = {
				'scip',
				'.',
			},
			filetypes = {
				rust = true,
			},
			markers = {
				'.git',
				'Cargo.toml',
			},
		},
		typescript = {
			command = 'scip-typescript',
			args = function(context)
				return typescript_args(context.root)
			end,
			filetypes = {
				javascript = true,
				javascriptreact = true,
				typescript = true,
				typescriptreact = true,
			},
			markers = {
				'.git',
				'jsconfig.json',
				'package.json',
				'tsconfig.json',
			},
		},
	},
}

---@type QompassScipConfig
M.config = vim.deepcopy(defaults)

M.state = {
	---@type vim.SystemObj|nil
	job = nil,
	---@type string|nil
	indexer = nil,
	---@type string|nil
	root = nil,
	started_at = 0,
}

local function notify(message, level)
	if not M.config.notify then
		return
	end

	vim.notify(message, level or vim.log.levels.INFO, {
		title = 'SCIP',
	})
end

---@param text string
---@return string[]
local function text_lines(text)
	if text == '' then
		return {
			'No output.',
		}
	end

	return vim.split(text:gsub('\r\n', '\n'), '\n', {
		plain = true,
		trimempty = true,
	})
end

---@param result vim.SystemCompleted
---@param prefer_stderr? boolean
---@return string
local function system_output(result, prefer_stderr)
	local stdout = result.stdout or ''
	local stderr = result.stderr or ''

	if prefer_stderr and stderr ~= '' then
		return stderr
	end
	if stdout ~= '' then
		return stdout
	end

	return stderr
end

---@param title string
---@param text string
---@param filetype? string
local function show_output(title, text, filetype)
	local bufnr = api.nvim_create_buf(false, true)
	api.nvim_buf_set_name(
		bufnr,
		string.format('scip://%s/%d', title:gsub('%s+', '-'):lower(), math.floor(vim.uv.hrtime()))
	)
	api.nvim_set_option_value('bufhidden', 'wipe', {
		buf = bufnr,
	})
	api.nvim_set_option_value('swapfile', false, {
		buf = bufnr,
	})
	api.nvim_buf_set_lines(bufnr, 0, -1, false, text_lines(text))
	api.nvim_set_option_value('filetype', filetype or 'text', {
		buf = bufnr,
	})
	api.nvim_set_option_value('modifiable', false, {
		buf = bufnr,
	})

	vim.cmd('botright new')
	api.nvim_win_set_buf(0, bufnr)
end

---@param title string
---@param result vim.SystemCompleted
local function show_failure(title, result)
	local output = system_output(result, true)
	fn.setqflist({}, 'r', {
		lines = text_lines(output),
		title = title,
	})
	vim.cmd('botright copen')
end

---@param bufnr? integer
---@param markers? string[]
---@return string
local function project_root(bufnr, markers)
	bufnr = bufnr or api.nvim_get_current_buf()
	local root = vim.fs.root(bufnr, markers or M.config.root_markers)
		or vim.fs.root(bufnr, M.config.root_markers)
		or fn.getcwd()

	return vim.fs.normalize(root)
end

---@param root string
---@return string
local function index_path(root)
	if vim.startswith(M.config.index_file, '/') then
		return vim.fs.normalize(M.config.index_file)
	end

	return vim.fs.joinpath(root, M.config.index_file)
end

---@param name string
---@return QompassScipIndexer|nil
local function get_indexer(name)
	local indexer = M.config.indexers[name]
	if not indexer or indexer.enabled == false then
		return nil
	end

	return indexer
end

---@param indexer QompassScipIndexer
---@param bufnr integer
---@return string|nil
local function matching_root(indexer, bufnr)
	local filetype = vim.bo[bufnr].filetype
	if not indexer.filetypes[filetype] then
		return nil
	end

	local root = vim.fs.root(bufnr, indexer.markers)
	if not root then
		return nil
	end

	return vim.fs.normalize(root)
end

---@param value string|fun(context: QompassScipContext): string
---@param context QompassScipContext
---@return string|nil
local function resolve_command(value, context)
	if type(value) == 'string' then
		return value
	end

	local ok, command = pcall(value, context)
	if not ok then
		notify(tostring(command), vim.log.levels.ERROR)
		return nil
	end
	if type(command) ~= 'string' or command == '' then
		notify('SCIP indexer command must resolve to a non-empty string', vim.log.levels.ERROR)
		return nil
	end

	return command
end

---@param bufnr integer
---@return string|nil, QompassScipIndexer|nil, string|nil, string|nil
local function detect_indexer(bufnr)
	local missing = {}

	for _, name in ipairs(M.config.indexer_order) do
		local indexer = get_indexer(name)
		if indexer then
			local root = matching_root(indexer, bufnr)
			if root then
				local context = {
					bufnr = bufnr,
					index_file = index_path(root),
					name = name,
					root = root,
				}
				local command = resolve_command(indexer.command, context)
				if command and fn.executable(command) == 1 then
					return name, indexer, root, command
				end
				if command then
					missing[#missing + 1] = command
				end
			end
		end
	end

	if #missing > 0 then
		notify('Missing SCIP indexer executable: ' .. table.concat(missing, ', '), vim.log.levels.ERROR)
	else
		notify('No configured SCIP indexer matches this buffer and project', vim.log.levels.WARN)
	end

	return nil, nil, nil, nil
end

---@param value string[]|fun(context: QompassScipContext): string[]
---@param context QompassScipContext
---@return string[]|nil
local function resolve_args(value, context)
	if type(value) == 'table' then
		return vim.deepcopy(value)
	end

	local ok, args = pcall(value, context)
	if not ok then
		notify(tostring(args), vim.log.levels.ERROR)
		return nil
	end

	return args
end

---@param root string
local function lint_after_index(root)
	if not M.config.lint_after_index or fn.executable('scip') ~= 1 then
		return
	end

	local file = index_path(root)
	if not path_exists(file) then
		notify('The indexer exited successfully but did not create ' .. file, vim.log.levels.WARN)
		return
	end

	vim.system({
		'scip',
		'lint',
		file,
	}, {
		cwd = root,
		text = true,
	}, function(result)
		vim.schedule(function()
			if result.code == 0 then
				notify('Index generated and validated: ' .. file)
			else
				notify('Index generated, but SCIP validation failed', vim.log.levels.ERROR)
				show_failure('SCIP lint', result)
			end
		end)
	end)
end

---@param name? string
---@param opts? { bufnr?: integer, root?: string }
function M.index(name, opts)
	if M.state.job then
		notify('An indexer is already running; use :ScipCancel first', vim.log.levels.WARN)
		return
	end

	opts = opts or {}
	local bufnr = opts.bufnr or api.nvim_get_current_buf()
	---@type QompassScipIndexer|nil
	local indexer
	---@type string|nil
	local root
	---@type string|nil
	local resolved_command

	if name and name ~= '' then
		indexer = get_indexer(name)
		if not indexer then
			notify('Unknown or disabled SCIP indexer: ' .. name, vim.log.levels.ERROR)
			return
		end
		root = opts.root and vim.fs.normalize(opts.root) or project_root(bufnr, indexer.markers)
	else
		name, indexer, root, resolved_command = detect_indexer(bufnr)
		if not name or not indexer or not root or not resolved_command then
			return
		end
	end

	local context = {
		bufnr = bufnr,
		index_file = index_path(root),
		name = name,
		root = root,
	}
	resolved_command = resolved_command or resolve_command(indexer.command, context)
	if not resolved_command then
		return
	end
	if fn.executable(resolved_command) ~= 1 then
		notify('SCIP indexer is not executable: ' .. resolved_command, vim.log.levels.ERROR)
		return
	end

	local args = resolve_args(indexer.args, context)
	if not args then
		return
	end

	local command = {
		resolved_command,
	}
	vim.list_extend(command, args)

	M.state.indexer = name
	M.state.root = root
	M.state.started_at = vim.uv.hrtime()
	notify('Indexing ' .. root .. ' with ' .. resolved_command)

	---@type vim.SystemObj
	local job
	job = vim.system(command, {
		cwd = root,
		text = true,
	}, function(result)
		vim.schedule(function()
			if M.state.job ~= job then
				return
			end

			M.state.job = nil
			local elapsed = (vim.uv.hrtime() - M.state.started_at) / 1e9
			if result.code ~= 0 then
				notify(string.format('%s failed after %.1f seconds', resolved_command, elapsed), vim.log.levels.ERROR)
				show_failure('SCIP: ' .. name, result)
				return
			end

			if M.config.lint_after_index and fn.executable('scip') == 1 then
				lint_after_index(root)
			else
				notify(string.format('Index generated in %.1f seconds: %s', elapsed, index_path(root)))
			end
		end)
	end)
	M.state.job = job
end

function M.cancel()
	if not M.state.job then
		notify('No SCIP indexer is running')
		return
	end

	M.state.job:kill(15)
	M.state.job = nil
	notify('SCIP indexing cancelled', vim.log.levels.WARN)
end

function M.status()
	if not M.state.job then
		notify('No SCIP indexer is running')
		return
	end

	local elapsed = (vim.uv.hrtime() - M.state.started_at) / 1e9
	notify(string.format('%s has been indexing %s for %.1f seconds', M.state.indexer, M.state.root, elapsed))
end

---@param command string[]
---@param title string
---@param filetype? string
local function run_scip(command, title, filetype)
	if fn.executable('scip') ~= 1 then
		notify('The scip CLI is not executable', vim.log.levels.ERROR)
		return
	end

	local root = project_root()
	local file = index_path(root)
	if not path_exists(file) then
		notify('No SCIP index exists at ' .. file, vim.log.levels.ERROR)
		return
	end

	local argv = {
		'scip',
	}
	vim.list_extend(argv, command)
	vim.system(argv, {
		cwd = root,
		text = true,
	}, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				notify(title .. ' failed', vim.log.levels.ERROR)
				show_failure(title, result)
				return
			end

			local output = system_output(result)
			show_output(title, output, filetype)
		end)
	end)
end

function M.lint()
	local root = project_root()
	run_scip({
		'lint',
		index_path(root),
	}, 'SCIP lint')
end

function M.stats()
	local root = project_root()
	run_scip({
		'stats',
		'--from',
		index_path(root),
	}, 'SCIP statistics')
end

function M.print()
	local root = project_root()
	run_scip({
		'print',
		'--json',
		index_path(root),
	}, 'SCIP index', 'json')
end

function M.snapshot()
	local root = project_root()
	local destination = vim.fs.joinpath(root, 'scip-snapshot')
	run_scip({
		'snapshot',
		'--from',
		index_path(root),
		'--to',
		destination,
	}, 'SCIP snapshot')
end

local function indexer_names()
	local names = {}
	for name, indexer in pairs(M.config.indexers) do
		if indexer.enabled ~= false then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

---@param indexer QompassScipIndexer
---@return string[]
local function indexer_filetypes(indexer)
	local filetypes = {}
	for filetype, enabled in pairs(indexer.filetypes) do
		if enabled then
			filetypes[#filetypes + 1] = filetype
		end
	end
	table.sort(filetypes)
	return filetypes
end

function M.coverage()
	local bufnr = api.nvim_get_current_buf()
	local current_filetype = vim.bo[bufnr].filetype
	local lines = {
		'SCIP indexer coverage',
		'',
		'Current filetype: ' .. (current_filetype ~= '' and current_filetype or '<none>'),
		'',
	}
	local current_matches = {}

	for _, name in ipairs(indexer_names()) do
		local indexer = M.config.indexers[name]
		if indexer then
			local root = project_root(bufnr, indexer.markers)
			local context = {
				bufnr = bufnr,
				index_file = index_path(root),
				name = name,
				root = root,
			}
			local command = resolve_command(indexer.command, context)
			local readiness = command and fn.executable(command) == 1 and 'ready' or 'missing'
			local filetypes = indexer_filetypes(indexer)

			lines[#lines + 1] = string.format(
				'%-12s %-8s %-24s %s',
				name,
				readiness,
				command or '<invalid command>',
				table.concat(filetypes, ', ')
			)

			if indexer.filetypes[current_filetype] then
				current_matches[#current_matches + 1] = name
			end
		end
	end

	lines[#lines + 1] = ''
	if #current_matches == 0 then
		lines[#lines + 1] = 'No SCIP generator is configured for the current filetype.'
		lines[#lines + 1] = 'Its Neovim LSP configuration remains available independently of SCIP.'
	else
		lines[#lines + 1] = 'Current filetype indexer: ' .. table.concat(current_matches, ', ')
	end

	show_output('SCIP coverage', table.concat(lines, '\n'))
end

---@param name string
---@param indexer QompassScipIndexer
function M.register(name, indexer)
	if type(name) ~= 'string' or name == '' then
		error('SCIP indexer name must be a non-empty string')
	end
	if type(indexer) ~= 'table' then
		error('SCIP indexer definition must be a table')
	end
	if type(indexer.command) ~= 'string' and type(indexer.command) ~= 'function' then
		error('SCIP indexer command must be a string or function')
	end
	if type(indexer.args) ~= 'table' and type(indexer.args) ~= 'function' then
		error('SCIP indexer args must be a table or function')
	end
	if type(indexer.filetypes) ~= 'table' or type(indexer.markers) ~= 'table' then
		error('SCIP indexer filetypes and markers must be tables')
	end

	M.config.indexers[name] = vim.deepcopy(indexer)
	if not vim.tbl_contains(M.config.indexer_order, name) then
		M.config.indexer_order[#M.config.indexer_order + 1] = name
	end
	table.sort(M.config.indexer_order)
end

local function create_commands()
	api.nvim_create_user_command('ScipCancel', M.cancel, {
		desc = 'Cancel the active SCIP indexer',
		force = true,
	})

	api.nvim_create_user_command('ScipCoverage', M.coverage, {
		desc = 'Show configured SCIP language coverage and readiness',
		force = true,
	})

	api.nvim_create_user_command('ScipIndex', function(command)
		M.index(command.args)
	end, {
		complete = function()
			return indexer_names()
		end,
		desc = 'Generate a SCIP index for the current project',
		force = true,
		nargs = '?',
	})

	api.nvim_create_user_command('ScipLint', M.lint, {
		desc = 'Validate the current project index',
		force = true,
	})

	api.nvim_create_user_command('ScipPrint', M.print, {
		desc = 'Open the current project index as JSON',
		force = true,
	})

	api.nvim_create_user_command('ScipSnapshot', M.snapshot, {
		desc = 'Create a human-readable SCIP snapshot',
		force = true,
	})

	api.nvim_create_user_command('ScipStats', M.stats, {
		desc = 'Show statistics for the current project index',
		force = true,
	})

	api.nvim_create_user_command('ScipStatus', M.status, {
		desc = 'Show the active SCIP indexer',
		force = true,
	})
end

---@param opts? QompassScipConfigOpts
function M.setup(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts)
	table.sort(M.config.indexer_order)
	create_commands()
end

return M
