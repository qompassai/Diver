-- /qompassai/Diver/lua/linters/eslint_d.lua
-- Qompass AI Diver Native eslint_d Linter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
local diagnostic = vim.diagnostic
---@class ESLintMessage
---@field column? integer
---@field endColumn? integer
---@field endLine? integer
---@field fatal? boolean
---@field line? integer
---@field message? string
---@field messageId? string
---@field ruleId? string
---@field severity? integer

---@class ESLintResult
---@field filePath? string
---@field messages? ESLintMessage[]

---@param value any
---@param fallback integer
---@return integer
local function integer(value, fallback)
	local parsed = tonumber(value)
	if parsed == nil then
		return fallback
	end
	return math.floor(parsed)
end

---@param value any
---@param fatal? boolean
---@return integer
local function severity(value, fatal)
	if fatal or integer(value, 0) >= 2 then
		return diagnostic.severity.ERROR
	end
	if integer(value, 0) == 1 then
		return diagnostic.severity.WARN
	end
	return diagnostic.severity.INFO
end

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
	if vim.trim(output) == '' then
		return {}
	end

	local ok, decoded = pcall(vim.json.decode, output)
	if not ok or type(decoded) ~= 'table' then
		error(('invalid eslint_d JSON: %s'):format(vim.trim(output)), 0)
	end

	---@cast decoded ESLintResult[]
	local diagnostics = {}
	for _, result in ipairs(decoded) do
		if type(result) == 'table' and type(result.messages) == 'table' then
			for _, record in ipairs(result.messages) do
				if type(record) == 'table' then
					local start_line = math.max(integer(record.line, 1) - 1, 0)
					local start_column = math.max(integer(record.column, 1) - 1, 0)
					local end_line = math.max(integer(record.endLine, start_line + 1) - 1, start_line)
					local minimum_end_column = end_line == start_line and start_column + 1 or 0
					local end_column =
						math.max(integer(record.endColumn, minimum_end_column + 1) - 1, minimum_end_column)
					local rule = tostring(record.ruleId or '')
					local message = tostring(record.message or 'Unknown ESLint diagnostic')
					if rule ~= '' then
						message = ('[%s] %s'):format(rule, message)
					end
					diagnostics[#diagnostics + 1] = {
						lnum = start_line,
						end_lnum = end_line,
						col = start_column,
						end_col = end_column,
						message = message,
						severity = severity(record.severity, record.fatal),
						source = 'eslint_d',
						code = rule ~= '' and rule or record.messageId,
					}
				end
			end
		end
	end

	return diagnostics
end

return ---@type Linter
{
	cmd = 'eslint_d',
	args = function(context)
		return {
			'--format=json',
			'--no-color',
			'--stdin',
			'--stdin-filename',
			context.filename,
		}
	end,
	append_fname = false,
	env = {
		ESLINT_D_MISS = 'fail',
		ESLINT_D_PPID = tostring(vim.fn.getpid()),
	},
	exit_codes = {
		[0] = true,
		[1] = true,
	},
	parser = parse,
	root_markers = {
		'eslint.config.js',
		'eslint.config.cjs',
		'eslint.config.mjs',
		'eslint.config.ts',
		'package.json',
		'.git',
	},
	stdin = true,
	stream = 'stdout',
	timeout = 30000,
}
