-- qompassai/Diver/lua/config/core/lint.lua
-- Qompass AI Diver Core Linter Config
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
local M = {}
local api = vim.api
local fn = vim.fn
local ERROR = vim.log.levels.ERROR

---@class qompass.lint.Opts
---@field bufnr? integer
---@field name? string

---@class qompass.lint.Output
---@field stdout string[]
---@field stderr string[]

local lint_group = api.nvim_create_augroup('Lint', {
	clear = true,
})
api.nvim_create_autocmd({
	'BufWritePost',
	'InsertLeave',
}, {
	group = lint_group,
	callback = function(args)
		M.lint({
			bufnr = args.buf,
		})
	end,
})

vim.cmd([[
    iabbr cosnt const
    iabbr imprt import
    iabbr imoprt import
    iabbr udpate update
    iabbr imrpvoe improve
    iabbr ipmrove improve
    iabbr imrpve improve
    iabbr imprve improve
    iabbr Imrpvoe Improve
    iabbr Ipmrove Improve
    iabbr Imrpve Improve
    iabbr Imprve Improve
    iabbr funcition function
    iabbr funciton function
    iabbr fucntion function
    iabbr functoin function
    iabbr funtion function
    iabbr fucntoin function
    iabbr aciton action
    iabbr acton action
    iabbr actoin action
    iabbr actin action
    iabbr ation action
    iabbr actoins actions
    iabbr acitns actions
    iabbr resposne response
    iabbr respnse response
    iabbr reponse response
    iabbr respone response
    iabbr resonse response
    iabbr resopnse response
    iabbr resposnes responses
    iabbr respnses responses
    iabbr reponses responses
    iabbr transation transaction
    iabbr transaciton transaction
    iabbr transacton transaction
    iabbr transction transaction
    iabbr trasaction transaction
    iabbr trasnsaction transaction
    iabbr transactoin transaction
    iabbr transactoins transactions
    iabbr transations transactions
    iabbr transacitons transactions
    iabbr transactons transactions
    iabbr transctions transactions
    iabbr repot report
    iabbr reort report
    iabbr rport report
    iabbr reprt report
    iabbr reoprt report
    iabbr repots reports
    iabbr reorts reports
    iabbr rports reports
    iabbr repotAction reportAction
    iabbr reportAciton reportAction
    iabbr reportActoin reportAction
    iabbr reprotAction reportAction
    iabbr reoprtAction reportAction
    iabbr reprtAction reportAction
    iabbr Onxy Onyx
    iabbr Onix Onyx
    iabbr Onyix Onyx
    iabbr Onxyx Onyx
    iabbr onxy onyx
    iabbr onix onyx
    iabbr onyix onyx
    iabbr onxyx onyx
    iabbr transationID transactionID
    iabbr transacitonID transactionID
    iabbr transactonID transactionID
    iabbr transctionID transactionID
    iabbr trasactionID transactionID
    iabbr trasnsactionID transactionID
    iabbr transactoinID transactionID
    iabbr repotActionID reportActionID
    iabbr reportAcitonID reportActionID
    iabbr reportActoinID reportActionID
    iabbr reprotActionID reportActionID
    iabbr reoprtActionID reportActionID
    iabbr reprtActionID reportActionID
    iabbr repotID reportID
    iabbr reortID reportID
    iabbr rportID reportID
    iabbr reprtID reportID
    iabbr reoprtID reportID
]])

---@type table<integer, table<string, integer>>
local running_procs_by_buf = {}
local namespaces = setmetatable({}, {
	__index = function(tbl, key)
		---@cast key string
		local namespace = api.nvim_create_namespace(key)
		rawset(tbl, key, namespace)
		return namespace
	end,
})

---@param name string
---@return integer
function M.get_namespace(name)
	return namespaces[name]
end

---@param bufnr? integer
---@return string[]
function M.get_running(bufnr)
	---@type string[]
	local linters = {}

	if bufnr ~= nil then
		if bufnr == 0 then
			bufnr = api.nvim_get_current_buf()
		end

		local running = running_procs_by_buf[bufnr] or {}
		for linter_name in pairs(running) do
			table.insert(linters, linter_name)
		end
	else
		for _, running in pairs(running_procs_by_buf) do
			for linter_name in pairs(running) do
				table.insert(linters, linter_name)
			end
		end
	end

	table.sort(linters)
	return linters
end

---@type {linters_by_ft?: table<string, string[]>}
local linters_root = require('linters')
---@type table<string, string[]>
local linters_by_ft = linters_root.linters_by_ft or {}
---@type table<string, vim.lint.Config|false>
local linter_specs = {}

---@param name string
---@return vim.lint.Config?
local function get_linter_spec(name)
	local cached = linter_specs[name]
	if cached ~= nil then
		return cached or nil
	end

	local ok, spec = pcall(require, 'linters.' .. name)
	if not ok then
		vim.notify(string.format('lint: failed to load linter %q: %s', name, spec), ERROR)
		linter_specs[name] = false
		return nil
	end

	---@cast spec vim.lint.Config
	linter_specs[name] = spec
	return spec
end

local root_markers = {
	'.git',
	'settings.gradle.kts',
	'settings.gradle',
	'build.gradle.kts',
	'build.gradle',
}

---@param bufnr integer
---@return vim.lint.Context
local function make_context(bufnr)
	local filename = api.nvim_buf_get_name(bufnr)
	local cwd = '.'
	local process_cwd = vim.uv.cwd()

	if type(process_cwd) == 'string' and process_cwd ~= '' then
		cwd = process_cwd
	end

	if filename ~= '' then
		local root = vim.fs.root(filename, root_markers)
		if type(root) == 'string' and root ~= '' then
			cwd = root
		else
			local parent = vim.fs.dirname(filename)
			if type(parent) == 'string' and parent ~= '' then
				cwd = parent
			end
		end
	end

	---@type vim.lint.Context
	local context = {
		bufnr = bufnr,
		cwd = cwd,
		filename = filename,
		filetype = vim.bo[bufnr].filetype,
	}

	return context
end

---@param name string
---@param spec vim.lint.Config
---@param context vim.lint.Context
---@return string?
local function resolve_cwd(name, spec, context)
	local value = spec.cwd

	if value == nil then
		return context.cwd
	end

	if type(value) == 'string' then
		if value ~= '' then
			return value
		end
	elseif type(value) == 'function' then
		---@cast value fun(context: vim.lint.Context): string
		local ok, resolved = pcall(value, context)
		if not ok then
			vim.notify(string.format('lint: failed to resolve working directory for %s: %s', name, resolved), ERROR)
			return nil
		end

		if type(resolved) == 'string' and resolved ~= '' then
			return resolved
		end
	end

	vim.notify(string.format('lint: working directory for %s must resolve to a non-empty string', name), ERROR)
	return nil
end

---@param name string
---@param spec vim.lint.Config
---@param context vim.lint.Context
---@return string[]?
local function resolve_args(name, spec, context)
	local value = spec.args

	if value == nil then
		return {}
	end

	if type(value) == 'table' then
		---@cast value string[]
		return vim.deepcopy(value)
	end

	if type(value) ~= 'function' then
		vim.notify(string.format('lint: arguments for %s must be a list or function', name), ERROR)
		return nil
	end

	---@cast value fun(context: vim.lint.Context): string[]
	local ok, resolved = pcall(value, context)
	if not ok then
		vim.notify(string.format('lint: failed to resolve arguments for %s: %s', name, resolved), ERROR)
		return nil
	end

	if not vim.islist(resolved) then
		vim.notify(string.format('lint: argument function for %s must return a list', name), ERROR)
		return nil
	end

	---@cast resolved string[]
	return resolved
end

---@param name string
---@param spec vim.lint.Config
---@return string?
local function resolve_cmd(name, spec)
	local value = spec.cmd

	if type(value) == 'string' and value ~= '' then
		return value
	end

	vim.notify(string.format('lint: command for %s must be a non-empty string', name), ERROR)
	return nil
end

---@param name string
---@param spec vim.lint.Config
---@param output string
---@param bufnr integer
---@return vim.Diagnostic[]?
local function parse_output(name, spec, output, bufnr)
	local parser = spec.parser
	if parser == nil then
		return {}
	end

	if type(parser) ~= 'function' then
		vim.notify(string.format('lint: parser for %s must be a function', name), ERROR)
		return nil
	end

	---@cast parser fun(output: string, bufnr: integer): vim.Diagnostic[]
	local ok, diagnostics = pcall(parser, output, bufnr)
	if not ok then
		vim.notify(string.format('lint: parser failed for %s: %s', name, diagnostics), ERROR)
		return nil
	end

	if type(diagnostics) ~= 'table' then
		vim.notify(string.format('lint: parser for %s must return diagnostics', name), ERROR)
		return nil
	end

	---@cast diagnostics vim.Diagnostic[]
	return diagnostics
end

---@param name string
---@param bufnr? integer
local function run_linter(name, bufnr)
	if bufnr == nil or bufnr == 0 then
		bufnr = api.nvim_get_current_buf()
	end

	if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
		return
	end

	local spec = get_linter_spec(name)
	if spec == nil then
		return
	end

	local context = make_context(bufnr)
	local cwd = resolve_cwd(name, spec, context)
	if cwd == nil then
		return
	end
	context.cwd = cwd

	local cmd = resolve_cmd(name, spec)
	if cmd == nil then
		return
	end

	local args = resolve_args(name, spec, context)
	if args == nil then
		return
	end

	---@type string[]
	local cmdline = { cmd }
	vim.list_extend(cmdline, args)

	if spec.append_fname ~= false and context.filename ~= '' then
		table.insert(cmdline, context.filename)
	end

	local stdin = spec.stdin == true
	local text
	if stdin then
		text = table.concat(api.nvim_buf_get_lines(bufnr, 0, -1, false), '\n')
	end

	running_procs_by_buf[bufnr] = running_procs_by_buf[bufnr] or {}

	local running = running_procs_by_buf[bufnr]
	local previous_job = running[name]
	if previous_job ~= nil and previous_job > 0 then
		running[name] = nil
		fn.jobstop(previous_job)
	end

	local namespace = M.get_namespace(name)
	---@type qompass.lint.Output
	local output = {
		stdout = {},
		stderr = {},
	}
	local changedtick = api.nvim_buf_get_changedtick(bufnr)

	local job_id = fn.jobstart(cmdline, {
		cwd = context.cwd,
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data ~= nil then
				vim.list_extend(output.stdout, data)
			end
		end,
		on_stderr = function(_, data)
			if data ~= nil then
				vim.list_extend(output.stderr, data)
			end
		end,
		on_exit = function(exited_job_id)
			local current = running_procs_by_buf[bufnr]
			if current == nil or current[name] ~= exited_job_id then
				return
			end

			current[name] = nil
			if next(current) == nil then
				running_procs_by_buf[bufnr] = nil
			end

			if
				not api.nvim_buf_is_valid(bufnr)
				or not api.nvim_buf_is_loaded(bufnr)
				or api.nvim_buf_get_changedtick(bufnr) ~= changedtick
			then
				return
			end

			---@type string[]
			local lines = {}
			local stream = spec.stream or 'stdout'
			if stream == 'stderr' then
				vim.list_extend(lines, output.stderr)
			elseif stream == 'both' then
				vim.list_extend(lines, output.stdout)
				vim.list_extend(lines, output.stderr)
			else
				vim.list_extend(lines, output.stdout)
			end

			local diagnostics = parse_output(name, spec, table.concat(lines, '\n'), bufnr)
			if diagnostics == nil then
				return
			end
			vim.diagnostic.set(namespace, bufnr, diagnostics, {})
		end,
	})

	if job_id <= 0 then
		vim.notify(string.format('lint: failed to start %s using command %s', name, cmd), ERROR)
		return
	end

	running[name] = job_id

	if stdin and text ~= nil then
		fn.chansend(job_id, text)
		fn.chanclose(job_id, 'stdin')
	end
end

---@param opts? integer|qompass.lint.Opts
function M.lint(opts)
	---@type qompass.lint.Opts
	local normalized = {}

	if type(opts) == 'table' then
		normalized = opts
	elseif type(opts) == 'number' then
		normalized.bufnr = opts
	end
	local bufnr = normalized.bufnr or api.nvim_get_current_buf()
	if bufnr == 0 then
		bufnr = api.nvim_get_current_buf()
	end
	if not api.nvim_buf_is_valid(bufnr) or not api.nvim_buf_is_loaded(bufnr) then
		return
	end
	if normalized.name ~= nil then
		run_linter(normalized.name, bufnr)
		return
	end
	local filetype = vim.bo[bufnr].filetype
	local names = linters_by_ft[filetype]
	if names == nil then
		return
	end

	for _, name in ipairs(names) do
		run_linter(name, bufnr)
	end
end

return M
