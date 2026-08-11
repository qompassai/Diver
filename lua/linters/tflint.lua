-- /qompassai/Diver/lua/linters/tflint.lua
-- Qompass AI Diver Native TFLint Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic

---@class TFLintPosition
---@field column? integer
---@field line? integer

---@class TFLintRange
---@field filename? string
---@field start? TFLintPosition
---@field end? TFLintPosition

---@class TFLintRule
---@field name? string
---@field severity? string

---@class TFLintIssue
---@field message? string
---@field range? TFLintRange
---@field rule? TFLintRule
---@field severity? string

---@class TFLintOutput
---@field errors? TFLintIssue[]
---@field issues? TFLintIssue[]

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
---@return integer
local function severity(value)
	local name = tostring(value or ''):lower()
	if name == 'error' then
		return diagnostic.severity.ERROR
	end
	if name == 'notice' or name == 'info' or name == 'information' then
		return diagnostic.severity.INFO
	end
	return diagnostic.severity.WARN
end

---@param filename? string
---@param context LintContext
---@return boolean
local function belongs_to_buffer(filename, context)
	if filename == nil or filename == '' then
		return true
	end
	---@type string
	local buffer_filename = vim.fs.normalize(context.filename) or context.filename
	---@type string
	local candidate
	if filename:sub(1, 1) == '/' then
		candidate = vim.fs.normalize(filename) or filename
	else
		local directory = vim.fs.dirname(context.filename) or context.cwd
		local joined = vim.fs.joinpath(directory, filename)
		candidate = vim.fs.normalize(joined) or joined
	end
	return candidate == buffer_filename or vim.fs.basename(candidate) == vim.fs.basename(buffer_filename)
end

---@param record TFLintIssue
---@param context LintContext
---@return vim.Diagnostic.Set?
local function diagnostic_from(record, context)
	---@type TFLintRange
	local range = type(record.range) == 'table' and record.range or {}
	if not belongs_to_buffer(range.filename, context) then
		return nil
	end

	---@type TFLintPosition
	local start = type(range.start) == 'table' and range.start or {}
	---@type TFLintPosition
	local finish = type(range['end']) == 'table' and range['end'] or {}
	local start_line = math.max(integer(start.line, 1) - 1, 0)
	local start_column = math.max(integer(start.column, 1) - 1, 0)
	local end_line = math.max(integer(finish.line, start_line + 1) - 1, start_line)
	local minimum_end_column = end_line == start_line and start_column + 1 or 0
	local end_column = math.max(integer(finish.column, minimum_end_column + 1) - 1, minimum_end_column)
	local rule_record = record.rule
	local rule = type(rule_record) == 'table' and tostring(rule_record.name or '') or ''
	local rule_severity = type(rule_record) == 'table' and rule_record.severity or nil
	local message = tostring(record.message or 'Unknown TFLint diagnostic')
	if rule ~= '' then
		message = ('[%s] %s'):format(rule, message)
	end

	return {
		lnum = start_line,
		end_lnum = end_line,
		col = start_column,
		end_col = end_column,
		message = message,
		severity = severity(rule_severity or record.severity),
		source = 'tflint',
		code = rule ~= '' and rule or nil,
	}
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
	if vim.trim(output) == '' then
		return {}
	end
	if type(context) ~= 'table' then
		error('tflint parser requires a LintContext', 0)
	end

	local ok, decoded = pcall(vim.json.decode, output)
	if not ok or type(decoded) ~= 'table' then
		error(('invalid TFLint JSON: %s'):format(vim.trim(output)), 0)
	end

	---@cast decoded TFLintOutput
	---@cast context LintContext
	local diagnostics = {}
	local groups = {
		decoded.issues or {},
		decoded.errors or {},
	}
	for _, records in ipairs(groups) do
		if type(records) == 'table' then
			for _, record in ipairs(records) do
				if type(record) == 'table' then
					local item = diagnostic_from(record, context)
					if item ~= nil then
						diagnostics[#diagnostics + 1] = item
					end
				end
			end
		end
	end

	return diagnostics
end

return ---@type Linter
{
	cmd = 'tflint',
	args = function(context)
		return {
			'--format=json',
			'--no-color',
			'--filter=' .. vim.fs.basename(context.filename),
		}
	end,
	append_fname = false,
	automatic = false,
	cwd = function(context)
		return vim.fs.dirname(context.filename) or context.cwd
	end,
	exit_codes = {
		[0] = true,
		[2] = true,
	},
	parser = parse,
	root_markers = {
		'.tflint.hcl',
		'.git',
	},
	stdin = false,
	stream = 'stdout',
	timeout = 60000,
}
