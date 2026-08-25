-- #################################################################
-- /qompassai/lua/linters/code_analyzer.lua
-- Qompass AI Code Analyzer
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
-- /qompassai/Diver/lua/linters/_salesforce-code-analyzer.lua
-- Qompass AI Diver Native Salesforce Code Analyzer Factory
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
local diagnostic = vim.diagnostic
---@class SalesforceAnalyzerLocation
---@field file? string
---@field startLine? integer
---@field startColumn? integer
---@field endLine? integer
---@field endColumn? integer

---@class SalesforceAnalyzerViolation
---@field engine? string
---@field locations? SalesforceAnalyzerLocation[]
---@field message? string
---@field primaryLocationIndex? integer
---@field rule? string
---@field ruleName? string
---@field severity? integer|string

---@class SalesforceAnalyzerOptions
---@field name string
---@field selector string

local M = {}

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
	local number = integer(value, 3)
	if number <= 2 then
		return diagnostic.severity.ERROR
	end
	if number == 3 then
		return diagnostic.severity.WARN
	end
	if number == 4 then
		return diagnostic.severity.INFO
	end
	return diagnostic.severity.HINT
end

---@param value any
---@param depth? integer
---@return SalesforceAnalyzerViolation[]?
local function find_violations(value, depth)
	if type(value) ~= 'table' or (depth or 0) > 6 then
		return nil
	end
	if type(value.violations) == 'table' then
		return value.violations
	end
	for _, key in ipairs({
		'result',
		'data',
		'output',
	}) do
		local found = find_violations(value[key], (depth or 0) + 1)
		if found ~= nil then
			return found
		end
	end
	return nil
end

---@param filename? string
---@param context LintContext
---@return boolean
local function belongs_to_buffer(filename, context)
	if filename == nil or filename == '' then
		return true
	end
	filename = filename:gsub('^file://', '')
	---@type string
	local buffer_filename = vim.fs.normalize(context.filename) or context.filename
	---@type string
	local candidate
	if vim.fs.is_absolute(filename) then
		candidate = vim.fs.normalize(filename) or filename
	else
		local joined = vim.fs.joinpath(context.root, filename)
		candidate = vim.fs.normalize(joined) or joined
	end
	return candidate == buffer_filename or vim.fs.basename(candidate) == vim.fs.basename(buffer_filename)
end

---@param record SalesforceAnalyzerViolation
---@param context LintContext
---@param source string
---@return vim.Diagnostic.Set?
local function diagnostic_from(record, context, source)
	local locations = type(record.locations) == 'table' and record.locations or {}
	local index = math.max(integer(record.primaryLocationIndex, 0), 0) + 1
	---@type SalesforceAnalyzerLocation
	local location = type(locations[index]) == 'table' and locations[index] or {}
	if not belongs_to_buffer(location.file, context) then
		return nil
	end

	local start_line = math.max(integer(location.startLine, 1) - 1, 0)
	local start_column = math.max(integer(location.startColumn, 1) - 1, 0)
	local end_line = math.max(integer(location.endLine, start_line + 1) - 1, start_line)
	local minimum_end_column = end_line == start_line and start_column + 1 or 0
	local end_column = math.max(integer(location.endColumn, minimum_end_column + 1) - 1, minimum_end_column)
	local engine = tostring(record.engine or '')
	local rule = tostring(record.rule or record.ruleName or '')
	local code = engine ~= '' and rule ~= '' and (engine .. ':' .. rule) or rule
	local message = tostring(record.message or 'Unknown Salesforce Code Analyzer violation')
	if code ~= '' then
		message = ('[%s] %s'):format(code, message)
	end

	return {
		lnum = start_line,
		end_lnum = end_line,
		col = start_column,
		end_col = end_column,
		message = message,
		severity = severity(record.severity),
		source = source,
		code = code ~= '' and code or nil,
	}
end

---@param options SalesforceAnalyzerOptions
---@return Linter
function M.new(options)
	return {
		cmd = 'sf',
		args = function(context)
			return {
				'code-analyzer',
				'run',
				'--json',
				'--rule-selector',
				options.selector,
				'--workspace',
				context.root,
				'--target',
				context.filename,
			}
		end,
		append_fname = false,
		automatic = false,
		cwd = function(context)
			return context.root
		end,
		exit_codes = {
			[0] = true,
		},
		parser = function(output, context)
			if vim.trim(output) == '' then
				return {}
			end
			if type(context) ~= 'table' then
				error(options.name .. ' parser requires a LintContext', 0)
			end
			local ok, decoded = pcall(vim.json.decode, output)
			if not ok or type(decoded) ~= 'table' then
				error(('invalid Salesforce Code Analyzer JSON: %s'):format(vim.trim(output)), 0)
			end
			---@cast context LintContext
			local records = find_violations(decoded) or {}
			local diagnostics = {}
			for _, record in ipairs(records) do
				if type(record) == 'table' then
					local item = diagnostic_from(record, context, options.name)
					if item ~= nil then
						diagnostics[#diagnostics + 1] = item
					end
				end
			end
			return diagnostics
		end,
		root_markers = {
			'code-analyzer.yml',
			'code-analyzer.yaml',
			'sfdx-project.json',
			'.git',
		},
		stdin = false,
		stream = 'stdout',
		timeout = 120000,
	}
end

return M
