-- /qompassai/Diver/lua/linters/init.lua
-- Qompass AI Diver Native Linter Runner
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
------------------------------------------------
---@source https://github.com/mfussenegger/nvim-lint/tree/master/lua/lint/linters | https://megalinter.io/8/supported-linters/
local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn

local M = {}

---@alias LintStream 'stdout'|'stderr'|'both'

---@class LintContext
---@field bufnr integer
---@field cwd string
---@field filename string
---@field filetype string
---@field modified boolean
---@field root string

---@class Linter
---@field cmd string|string[]
---@field args? string[]|fun(context: LintContext): string[]
---@field append_fname? boolean
---@field automatic? boolean
---@field cwd? string|fun(context: LintContext): string
---@field env? table<string, string>
---@field errorformat? string|string[]
---@field exit_codes? table<integer, boolean>|integer[]
---@field ignore_exitcode? boolean
---@field parser? fun(output: string, context: LintContext|integer): vim.Diagnostic.Set[]
---@field root_markers? string[]
---@field stdin? boolean
---@field stream? LintStream
---@field timeout? integer

---@class LintOptions
---@field debounce_ms integer
---@field enabled boolean
---@field events string[]
---@field max_file_size integer
---@field notify_missing boolean

---@class LintSetupOptions
---@field debounce_ms? integer
---@field enabled? boolean
---@field events? string[]
---@field max_file_size? integer
---@field notify_missing? boolean

---@type LintOptions
M.options = {
	debounce_ms = 250,
	enabled = true,
	events = {
		'BufReadPost',
		'BufWritePost',
		'InsertLeave',
	},
	max_file_size = 1024 * 1024,
	notify_missing = false,
}

---@type table<string, string>
M.module_sources = {
	actionlint = 'linters.actionlint',
	ameba = 'linters.ameba',
	ansible_lint = 'linters.ansible_lint',
	apkbuild_lint = 'linters.apkbuild-lint',
	bandit = 'linters.bandit',
	bashate = 'linters.bashate',
	bashlint = 'linters.bashlint',
	bibclean = 'linters.bibclean',
	bootlint = 'linters.bootlint',
	buildifier = 'linters.buildifier',
	checkbashisms = 'linters.checkbashisms',
	checkpatch = 'linters.checkpatch',
	chktex = 'linters.chktex',
	clippy = 'linters.clippy',
	clj_kondo = 'linters.clj-kondo',
	cmake_lint = 'linters.cmake-lint',
	cookstyle = 'linters.cookstyle',
	cppcheck = 'linters.cppcheck',
	csslint = 'linters.csslint',
	cypher_lint = 'linters.cypher-lint',
	cython_lint = 'linters.cython-lint',
	deadnix = 'linters.deadnix',
	desktopval = 'linters.desktopval',
	djlint = 'linters.djlint',
	dotenv_linter = 'linters.dotenv-linter',
	eslint_d = 'linters.eslint_d',
	golangcilint = 'linters.golangcilint',
	hadolint = 'linters.hadolint',
	html_validate = 'linters.html_validate',
	htmlhint = 'linters.htmlhint',
	joker = 'linters.joker',
	ktlint = 'linters.ktlint',
	lacheck = 'linters.lacheck',
	lint_openapi = 'linters.lint-openapi',
	llvm_mc = 'linters.llvm-mc',
	luac = 'linters.luac',
	luacheck = 'linters.luacheck',
	mado = 'linters.mado',
	markdownlint = 'linters.markdownlint',
	mdl = 'linters.mdl',
	naga = 'linters.naga',
	nvcc = 'linters.nvcc',
	oxlint = 'linters.oxlint',
	proselint = 'linters.proselint',
	pyrefly = 'linters.pyrefly',
	psscriptanalyzer = 'linters.psscryptanalyzer',
	puppet_lint = 'linters.puppet-lint',
	remark_lint = 'linters.remark-lint',
	revive = 'linters.revive',
	rumdl = 'linters.rumdl',
	scalastyle = 'linters.scalastyle',
	scarb = 'linters.scarb',
	shellcheck = 'linters.shellcheck',
	sphinx_lint = 'linters.sphinx-lint',
	statix = 'linters.statix',
	stylelint = 'linters.stylelint',
	textlint = 'linters.textlint',
	tflint = 'linters.tflint',
	vint = 'linters.vint',
	vulture = 'linters.vulture',
	yamllint = 'linters.yamllint',
	yara = 'linters.yara',
	zlint = 'linters.zlint',
}
M.definitions = {} ---@type table<string, Linter>
M.load_errors = {} ---@type table<string, string>
---@param name string
---@param module_name string
local function load_linter(name, module_name)
	local ok, result = pcall(require, module_name)
	if not ok then
		M.load_errors[name] = ('%s failed to load: %s'):format(module_name, tostring(result))
		return
	end
	if type(result) ~= 'table' then
		M.load_errors[name] = ('%s returned %s; its file must end with `return { ... }`'):format(
			module_name,
			type(result)
		)
		return
	end
	---@cast result Linter
	M.definitions[name] = result
end

for name, module_name in pairs(M.module_sources) do
	load_linter(name, module_name)
end

-- Keep the default set focused. Additional registered linters can be run with
-- :Lint <name> without producing duplicate diagnostics on every edit.
---@type table<string, string[]>
M.linters_by_ft = {
	ansible = {
		'ansible_lint',
	},
	apkbuild = {
		'apkbuild_lint',
	},
	asm = {
		'llvm_mc',
	},
	bash = {
		'shellcheck',
	},
	bazel = {
		'buildifier',
	},
	bib = {
		'bibclean',
	},
	bibtex = {
		'bibclean',
	},
	c = {
		'cppcheck',
	},
	cairo = {
		'scarb',
	},
	chef = {
		'cookstyle',
	},
	clojure = {
		'clj_kondo',
	},
	cmake = {
		'cmake_lint',
	},
	cpp = {
		'cppcheck',
	},
	crystal = {
		'ameba',
	},
	css = {
		'stylelint',
	},
	cuda = {
		'nvcc',
	},
	cypher = {
		'cypher_lint',
	},
	cython = {
		'cython_lint',
	},
	desktop = {
		'desktopval',
	},
	dockerfile = {
		'hadolint',
	},
	dotenv = {
		'dotenv_linter',
	},
	go = {
		'golangcilint',
	},
	html = {
		'html_validate',
	},
	htmlangular = {
		'djlint',
	},
	htmldjango = {
		'djlint',
	},
	javascript = {
		'oxlint',
	},
	javascriptreact = {
		'oxlint',
	},
	jinja = {
		'djlint',
	},
	jinja2 = {
		'djlint',
	},
	jsx = {
		'oxlint',
	},
	kotlin = {
		'ktlint',
	},
	latex = {
		'chktex',
	},
	lua = {
		'luacheck',
	},
	mail = {
		'proselint',
	},
	markdown = {
		'rumdl',
	},
	['markdown.mdx'] = {
		'rumdl',
	},
	nix = {
		'statix',
		'deadnix',
	},
	openapi = {
		'lint_openapi',
	},
	plaintex = {
		'chktex',
	},
	powershell = {
		'psscriptanalyzer',
	},
	puppet = {
		'puppet_lint',
	},
	python = {
		'bandit',
		--		'pyrefly',
		'vulture',
	},
	quarto = {
		'rumdl',
	},
	rst = {
		'sphinx_lint',
	},
	rust = {
		'clippy',
	},
	sass = {
		'stylelint',
	},
	scala = {
		'scalastyle',
	},
	scss = {
		'stylelint',
	},
	sh = {
		'checkbashisms',
		'shellcheck',
	},
	swagger = {
		'lint_openapi',
	},
	terraform = {
		'tflint',
	},
	['terraform-vars'] = {
		'tflint',
	},
	tex = {
		'chktex',
	},
	tsx = {
		'oxlint',
	},
	typescript = {
		'oxlint',
	},
	typescriptreact = {
		'oxlint',
	},
	vim = {
		'vint',
	},
	vue = {
		'eslint_d',
	},
	wgsl = {
		'naga',
	},
	yaml = {
		'yamllint',
	},
	['yaml.ansible'] = {
		'ansible_lint',
	},
	['yaml.ghaction'] = {
		'actionlint',
	},
	['yaml.github'] = {
		'actionlint',
	},
	['yaml.openapi'] = {
		'lint_openapi',
	},
	yara = {
		'yara',
	},
	yml = {
		'yamllint',
	},
	zig = {
		'zlint',
	},
	zine = {
		'zlint',
	},
	zon = {
		'zlint',
	},
}

-- These tools normally inspect or build an entire project and are therefore
-- available through :Lint but skipped by automatic buffer events.
---@type table<string, boolean>
M.manual_linters = {
	checkpatch = true,
	clippy = true,
	golangcilint = true,
	pyrefly = true,
	scalastyle = true,
	scarb = true,
	tflint = true,
	vulture = true,
}

local default_exit_codes = {
	[0] = true,
	[1] = true,
}

local default_root_markers = {
	'.git',
	'.hg',
	'.svn',
}
local severity_by_letter = {
	E = diagnostic.severity.ERROR,
	I = diagnostic.severity.INFO,
	N = diagnostic.severity.HINT,
	S = diagnostic.severity.HINT,
	W = diagnostic.severity.WARN,
}

local namespaces = {} ---@type table<string, integer>

---@type table<string, vim.SystemObj>
local jobs = {}

---@type table<string, integer>
local generations = {}

---@type table<integer, uv.uv_timer_t>
local timers = {}

---@type table<string, boolean>
local missing_reported = {}

---@param bufnr? integer
---@return integer
local function resolve_bufnr(bufnr)
	if bufnr == nil or bufnr == 0 then
		return api.nvim_get_current_buf()
	end
	return bufnr
end

---@param value string
---@return string
local function strip_ansi(value)
	return value:gsub('\27%[[%d;?]*[ -/]*[@-~]', '')
end

---@param value any
---@return integer?
local function integer(value)
	local parsed = tonumber(value)
	if parsed == nil then
		return nil
	end
	return math.floor(parsed)
end

---@param name string
---@return integer
local function namespace(name)
	local existing = namespaces[name]
	if existing ~= nil then
		return existing
	end
	local created = api.nvim_create_namespace('linter.' .. name)
	namespaces[name] = created
	return created
end

---@param errorformat string|string[]
---@return fun(output: string, context: LintContext|integer): vim.Diagnostic.Set[]
local function errorformat_parser(errorformat)
	local format = type(errorformat) == 'table' and table.concat(errorformat, ',') or errorformat
	return function(output, _)
		local parsed = fn.getqflist({
			efm = format,
			lines = vim.split(strip_ansi(output), '\n', {
				plain = true,
				trimempty = true,
			}),
		})
		local diagnostics = {}
		for _, item in ipairs(parsed.items or {}) do
			if item.valid == 1 then
				local item_type = type(item.type) == 'string' and item.type:upper() or 'E'
				local end_line = integer(item.end_lnum)
				local end_column = integer(item.end_col)
				local number = integer(item.nr)
				diagnostics[#diagnostics + 1] = {
					lnum = math.max((integer(item.lnum) or 1) - 1, 0),
					col = math.max((integer(item.col) or 1) - 1, 0),
					end_lnum = end_line and end_line > 0 and end_line - 1 or nil,
					end_col = end_column and end_column > 0 and end_column - 1 or nil,
					message = item.text ~= '' and item.text or 'Unknown linter diagnostic',
					severity = severity_by_letter[item_type:sub(1, 1)] or diagnostic.severity.ERROR,
					code = number and number > 0 and number or nil,
				}
			end
		end
		return diagnostics
	end
end

---@param parser function
---@param output string
---@param context LintContext
---@return boolean
---@return vim.Diagnostic.Set[]|string
local function invoke_parser(parser, output, context)
	local context_ok, context_result = pcall(parser, output, context)
	if context_ok and type(context_result) == 'table' then
		return true, context_result
	end
	local bufnr_ok, bufnr_result = pcall(parser, output, context.bufnr)
	if bufnr_ok and type(bufnr_result) == 'table' then
		return true, bufnr_result
	end
	local context_error = context_ok and ('returned ' .. type(context_result)) or tostring(context_result)
	local bufnr_error = bufnr_ok and ('returned ' .. type(bufnr_result)) or tostring(bufnr_result)
	return false, ('context parser: %s; buffer parser: %s'):format(context_error, bufnr_error)
end

---@param bufnr integer
---@return boolean
local function buffer_is_eligible(bufnr)
	if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
		return false
	end
	if vim.bo[bufnr].buftype ~= '' or vim.bo[bufnr].filetype == '' then
		return false
	end
	local filename = api.nvim_buf_get_name(bufnr)
	if filename == '' then
		return false
	end
	local maximum = M.options.max_file_size
	if maximum >= 0 then
		local size = fn.getfsize(filename)
		if size > maximum then
			return false
		end
	end
	return not vim.b[bufnr].lint_disabled
end

---@param bufnr integer
---@return string[]
local function configured_linters(bufnr)
	local configured = M.linters_by_ft[vim.bo[bufnr].filetype]
	return type(configured) == 'table' and configured or {}
end

---@param candidates string|string[]
---@return string?
local function executable(candidates)
	if type(candidates) == 'string' then
		return fn.executable(candidates) == 1 and candidates or nil
	end
	if type(candidates) ~= 'table' then
		return nil
	end
	for _, candidate in ipairs(candidates) do
		if fn.executable(candidate) == 1 then
			return candidate
		end
	end
	return nil
end

---@param bufnr integer
---@param markers? string[]
---@return string
local function project_root(bufnr, markers)
	local filename = api.nvim_buf_get_name(bufnr)
	return vim.fs.root(bufnr, markers or default_root_markers) or vim.fs.dirname(filename) or vim.uv.cwd() or '.'
end

---@param bufnr integer
---@param definition Linter
---@return LintContext
local function context_for(bufnr, definition)
	local raw_filename = api.nvim_buf_get_name(bufnr)
	---@type string
	local filename = vim.fs.normalize(raw_filename) or raw_filename
	---@type string
	local root = project_root(bufnr, definition.root_markers)
	---@type LintContext
	local context = {
		bufnr = bufnr,
		cwd = root,
		filename = filename,
		filetype = vim.bo[bufnr].filetype,
		modified = vim.bo[bufnr].modified == true,
		root = root,
	}
	return context
end

---@param definition Linter
---@param context LintContext
---@return string
local function resolve_cwd(definition, context)
	local configured_cwd = definition.cwd
	if type(configured_cwd) == 'function' then
		return configured_cwd(context)
	end
	if type(configured_cwd) == 'string' then
		return configured_cwd
	end
	return context.cwd
end

---@param executable_name string
---@param definition Linter
---@param context LintContext
---@return string[]
local function command_for(executable_name, definition, context)
	local command = { executable_name }
	local configured_args = definition.args
	if type(configured_args) == 'function' then
		vim.list_extend(command, configured_args(context))
	elseif type(configured_args) == 'table' then
		vim.list_extend(command, configured_args)
	end
	if definition.append_fname then
		command[#command + 1] = context.filename
	end
	for index, argument in ipairs(command) do
		if type(argument) ~= 'string' then
			error(('command argument %d has type %s instead of string'):format(index, type(argument)), 0)
		end
	end
	return command
end

---@param bufnr integer
---@return string
local function buffer_input(bufnr)
	local input = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
	return vim.bo[bufnr].endofline and (input .. '\n') or input
end

---@param result vim.SystemCompleted
---@param stream? LintStream
---@return string
local function result_output(result, stream)
	if stream == 'stderr' then
		return result.stderr or ''
	end
	if stream == 'both' then
		local stdout = result.stdout or ''
		local stderr = result.stderr or ''
		if stdout == '' then
			return stderr
		end
		if stderr == '' then
			return stdout
		end
		return stdout .. '\n' .. stderr
	end
	-- vim.lint.Config-compatible default.
	return result.stdout or ''
end

---@param definition Linter
---@param code integer
---@return boolean
local function accepts_exit_code(definition, code)
	if definition.ignore_exitcode then
		return true
	end
	local configured = definition.exit_codes or default_exit_codes
	if configured[code] == true then
		return true
	end
	for _, accepted in ipairs(configured) do
		if accepted == code then
			return true
		end
	end
	return false
end

---@param name string
---@param definition Linter
---@return boolean
local function runs_automatically(name, definition)
	return definition.automatic ~= false and not M.manual_linters[name]
end

---@param name string
---@param bufnr integer
---@param diagnostics vim.Diagnostic.Set[]
local function publish(name, bufnr, diagnostics)
	local line_count = math.max(api.nvim_buf_line_count(bufnr), 1)
	for _, item in ipairs(diagnostics) do
		item.lnum = math.min(math.max(integer(item.lnum) or 0, 0), line_count - 1)
		local start_col = math.max(integer(item.col) or 0, 0)
		item.col = start_col
		if item.end_lnum ~= nil then
			item.end_lnum = math.min(math.max(integer(item.end_lnum) or item.lnum, item.lnum), line_count - 1)
		end
		if item.end_col ~= nil then
			item.end_col = math.max(integer(item.end_col) or start_col, start_col)
		end
		item.message = tostring(item.message or 'Unknown linter diagnostic')
		item.severity = item.severity or diagnostic.severity.ERROR
		item.source = name
	end
	diagnostic.set(namespace(name), bufnr, diagnostics)
end

---@param name string
---@param bufnr? integer
---@param opts? { automatic?: boolean, notify?: boolean }
---@return boolean
function M.run_linter(name, bufnr, opts)
	opts = opts or {}
	bufnr = resolve_bufnr(bufnr)
	if not buffer_is_eligible(bufnr) then
		return false
	end

	local definition = M.definitions[name]
	if type(definition) ~= 'table' then
		diagnostic.reset(namespace(name), bufnr)
		if opts.notify then
			local reason = M.load_errors[name] or ('native linter %q is not registered'):format(name)
			vim.notify(reason, vim.log.levels.ERROR, {
				title = 'Native linters',
			})
		end
		return false
	end
	if opts.automatic and not runs_automatically(name, definition) then
		diagnostic.reset(namespace(name), bufnr)
		return false
	end

	local configured_cmd = definition.cmd
	local executable_name = executable(configured_cmd)
	if executable_name == nil then
		diagnostic.reset(namespace(name), bufnr)
		if opts.notify or (M.options.notify_missing and not missing_reported[name]) then
			missing_reported[name] = true
			---@type string
			local requested
			if type(configured_cmd) == 'table' then
				requested = table.concat(configured_cmd, ', ')
			else
				requested = configured_cmd
			end
			vim.notify(('Linter executable not found: %s'):format(requested), vim.log.levels.WARN)
		end
		return false
	end

	local context = context_for(bufnr, definition)
	if context.modified and not definition.stdin then
		diagnostic.reset(namespace(name), bufnr)
		if opts.notify then
			vim.notify(('%s reads the saved file; write the buffer before linting'):format(name), vim.log.levels.INFO)
		end
		return false
	end
	local command_ok, command_or_error = pcall(command_for, executable_name, definition, context)
	if not command_ok then
		diagnostic.reset(namespace(name), bufnr)
		vim.notify(('%s command failed: %s'):format(name, tostring(command_or_error)), vim.log.levels.ERROR)
		return false
	end
	---@cast command_or_error string[]
	local command = command_or_error
	local cwd_ok, cwd_or_error = pcall(resolve_cwd, definition, context)
	if not cwd_ok or type(cwd_or_error) ~= 'string' then
		diagnostic.reset(namespace(name), bufnr)
		vim.notify(('%s cwd failed: %s'):format(name, tostring(cwd_or_error)), vim.log.levels.ERROR)
		return false
	end
	diagnostic.reset(namespace(name), bufnr)
	local key = ('%d:%s'):format(bufnr, name)
	local previous = jobs[key]
	if previous ~= nil then
		pcall(previous.kill, previous, 15)
		jobs[key] = nil
	end
	local generation = (generations[key] or 0) + 1
	generations[key] = generation
	local changedtick = api.nvim_buf_get_changedtick(bufnr)
	local system_options = {
		cwd = cwd_or_error,
		env = vim.tbl_extend('keep', definition.env or {}, {
			NO_COLOR = '1',
		}),
		stdin = definition.stdin and buffer_input(bufnr) or nil,
		text = true,
		timeout = definition.timeout or 30000,
	}

	local job
	job = vim.system(command, system_options, function(result)
		vim.schedule(function()
			if generations[key] ~= generation then
				return
			end
			if jobs[key] == job then
				jobs[key] = nil
			end
			if not api.nvim_buf_is_valid(bufnr) then
				return
			end
			if api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
				return
			end

			local output = result_output(result, definition.stream)
			local parser = definition.parser or (definition.errorformat and errorformat_parser(definition.errorformat))
			if parser == nil then
				publish(name, bufnr, {})
				vim.notify(('Linter %q has no parser or errorformat'):format(name), vim.log.levels.ERROR)
				return
			end
			local parse_ok, parsed_or_error = invoke_parser(parser, output, context)
			if not parse_ok then
				publish(name, bufnr, {})
				vim.notify(('%s parser failed: %s'):format(name, tostring(parsed_or_error)), vim.log.levels.ERROR)
				return
			end
			---@cast parsed_or_error vim.Diagnostic.Set[]
			local parsed = parsed_or_error
			publish(name, bufnr, parsed)
			if not accepts_exit_code(definition, result.code) and #parsed == 0 then
				local detail = vim.trim(strip_ansi(output))
				if #detail > 300 then
					detail = detail:sub(1, 300) .. '…'
				end
				vim.notify(
					('%s failed with exit code %s%s'):format(
						name,
						tostring(result.code),
						detail ~= '' and (': ' .. detail) or ''
					),
					vim.log.levels.ERROR
				)
			end
		end)
	end)
	jobs[key] = job
	return true
end

---@param bufnr? integer
---@param opts? { automatic?: boolean, notify?: boolean }
---@param names? string[]
function M.run(bufnr, opts, names)
	bufnr = resolve_bufnr(bufnr)
	if not M.options.enabled or not buffer_is_eligible(bufnr) then
		return
	end
	local selected = names or configured_linters(bufnr)
	local active = {}
	for _, name in ipairs(selected) do
		active[name] = true
		M.run_linter(name, bufnr, opts)
	end
	if names == nil then
		for name, ns in pairs(namespaces) do
			if not active[name] then
				diagnostic.reset(ns, bufnr)
			end
		end
	end
end

---@param bufnr integer
local function cancel_timer(bufnr)
	local timer = timers[bufnr]
	if timer == nil then
		return
	end
	timers[bufnr] = nil
	if not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

---@param bufnr integer
---@param immediate? boolean
local function schedule(bufnr, immediate)
	cancel_timer(bufnr)
	if immediate then
		M.run(bufnr, { automatic = true })
		return
	end
	timers[bufnr] = vim.defer_fn(function()
		timers[bufnr] = nil
		M.run(bufnr, { automatic = true })
	end, M.options.debounce_ms)
end

---@param bufnr? integer
function M.stop(bufnr)
	bufnr = resolve_bufnr(bufnr)
	cancel_timer(bufnr)
	local prefix = tostring(bufnr) .. ':'
	for key, job in pairs(jobs) do
		if key:sub(1, #prefix) == prefix then
			generations[key] = (generations[key] or 0) + 1
			pcall(job.kill, job, 15)
			jobs[key] = nil
		end
	end
end

---@param bufnr? integer
function M.reset(bufnr)
	bufnr = resolve_bufnr(bufnr)
	M.stop(bufnr)
	for _, ns in pairs(namespaces) do
		diagnostic.reset(ns, bufnr)
	end
end

---@param name string
---@param definition Linter
function M.register(name, definition)
	vim.validate({
		name = { name, 'string' },
		definition = { definition, 'table' },
	})
	M.definitions[name] = definition
	M.load_errors[name] = nil
	missing_reported[name] = nil
end

---@return string[]
function M.validate()
	local problems = {}
	local valid_streams = {
		both = true,
		stderr = true,
		stdout = true,
	}

	for name, message in pairs(M.load_errors) do
		problems[#problems + 1] = ('linter %q: %s'):format(name, message)
	end

	for filetype, names in pairs(M.linters_by_ft) do
		if type(names) ~= 'table' then
			problems[#problems + 1] = ('filetype %q must map to a list'):format(filetype)
		else
			local seen = {}
			for _, name in ipairs(names) do
				if seen[name] then
					problems[#problems + 1] = ('filetype %q repeats %q'):format(filetype, name)
				end
				seen[name] = true
				if type(M.definitions[name]) ~= 'table' then
					problems[#problems + 1] = ('filetype %q references undefined linter %q'):format(filetype, name)
				end
			end
		end
	end

	for name, definition in pairs(M.definitions) do
		if type(definition) ~= 'table' then
			problems[#problems + 1] = ('linter %q has type %s instead of table'):format(name, type(definition))
		else
			if type(definition.cmd) ~= 'string' and type(definition.cmd) ~= 'table' then
				problems[#problems + 1] = ('linter %q has an invalid cmd'):format(name)
			end
			if definition.parser == nil and definition.errorformat == nil then
				problems[#problems + 1] = ('linter %q has no parser or errorformat'):format(name)
			end
			if definition.stream ~= nil and not valid_streams[definition.stream] then
				problems[#problems + 1] = ('linter %q has invalid stream %q'):format(name, definition.stream)
			end
		end
	end

	table.sort(problems)
	return problems
end

---@return string[]
local function registered_names()
	---@type table<string, boolean>
	local seen = {}
	for name in pairs(M.module_sources) do
		seen[name] = true
	end
	for name in pairs(M.definitions) do
		seen[name] = true
	end
	---@type string[]
	local names = vim.tbl_keys(seen)
	table.sort(names)
	return names
end

---@param bufnr? integer
---@param include_all? boolean
---@return string
function M.info(bufnr, include_all)
	bufnr = resolve_bufnr(bufnr)
	if not api.nvim_buf_is_valid(bufnr) then
		return 'Invalid buffer'
	end

	local filetype = vim.bo[bufnr].filetype
	local configured = include_all and registered_names() or configured_linters(bufnr)
	local lines = {
		('Buffer: %d'):format(bufnr),
		('Filetype: %s'):format(filetype ~= '' and filetype or '<none>'),
		('Automatic linting: %s'):format(
			M.options.enabled and not vim.b[bufnr].lint_disabled and 'enabled' or 'disabled'
		),
		include_all and 'Registered linters:' or 'Configured linters:',
	}
	if #configured == 0 then
		lines[#lines + 1] = '  <none>'
	end
	for _, name in ipairs(configured) do
		local definition = M.definitions[name]
		if type(definition) ~= 'table' then
			lines[#lines + 1] = ('  %s: unavailable (%s)'):format(name, M.load_errors[name] or 'invalid definition')
		else
			local resolved = executable(definition.cmd)
			local mode = runs_automatically(name, definition) and 'automatic' or 'manual'
			lines[#lines + 1] = ('  %s: %s (%s)'):format(name, resolved or 'missing', mode)
		end
	end
	return table.concat(lines, '\n')
end

---@param arglead string
---@return string[]
local function complete_linter(arglead)
	local matches = {}
	for _, name in ipairs(registered_names()) do
		if arglead == '' or vim.startswith(name, arglead) then
			matches[#matches + 1] = name
		end
	end
	return matches
end

---@param opts? LintSetupOptions
function M.setup(opts)
	if opts ~= nil then
		local merged = vim.tbl_deep_extend('force', M.options, opts)
		---@cast merged LintOptions
		M.options = merged
	end

	local problems = M.validate()
	if #problems > 0 then
		vim.notify(table.concat(problems, '\n'), vim.log.levels.ERROR, {
			title = 'Native linter configuration',
		})
	end

	local group = api.nvim_create_augroup('native_linters', { clear = true })
	api.nvim_create_autocmd(M.options.events, {
		group = group,
		desc = 'Run native asynchronous linters',
		callback = function(event)
			if M.options.enabled and buffer_is_eligible(event.buf) then
				schedule(event.buf, event.event == 'BufWritePost')
			end
		end,
	})
	api.nvim_create_autocmd('BufWipeout', {
		group = group,
		desc = 'Stop native linters and release buffer state',
		callback = function(event)
			M.stop(event.buf)
		end,
	})
	api.nvim_create_user_command('Lint', function(command)
		if #command.fargs == 0 then
			M.run(0, { notify = command.bang })
			return
		end
		M.run(0, { notify = true }, command.fargs)
	end, {
		bang = true,
		complete = complete_linter,
		desc = 'Lint the current buffer with configured or named linters',
		force = true,
		nargs = '*',
	})
	api.nvim_create_user_command('LintDisable', function()
		vim.b.lint_disabled = true
		M.reset(0)
	end, {
		desc = 'Disable native linting for the current buffer',
		force = true,
	})
	api.nvim_create_user_command('LintEnable', function()
		vim.b.lint_disabled = false
		M.run(0, { notify = true })
	end, {
		desc = 'Enable native linting for the current buffer',
		force = true,
	})
	api.nvim_create_user_command('LintInfo', function(command)
		vim.notify(M.info(0, command.bang), vim.log.levels.INFO, {
			title = 'Native linters',
		})
	end, {
		bang = true,
		desc = 'Show configured linters; use bang to show every registered linter',
		force = true,
	})
	api.nvim_create_user_command('LintReset', function()
		M.reset(0)
	end, {
		desc = 'Stop native linters and clear their diagnostics',
		force = true,
	})
	api.nvim_create_user_command('LintValidate', function()
		local validation_problems = M.validate()
		local message = #validation_problems == 0 and 'Native linter configuration is valid'
			or table.concat(validation_problems, '\n')
		vim.notify(message, #validation_problems == 0 and vim.log.levels.INFO or vim.log.levels.ERROR, {
			title = 'Native linters',
		})
	end, {
		desc = 'Validate the native linter registry',
		force = true,
	})
end
return M
