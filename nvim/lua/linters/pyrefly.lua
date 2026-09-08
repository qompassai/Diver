-- #################################################################
-- /qompassai/lua/linters/pyrefly.lua
-- Qompass AI Pyrefly
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
local diagnostic = vim.diagnostic
---@class PyreflyError
---@field code? integer|string
---@field column? integer
---@field concise_description? string
---@field description? string
---@field line? integer
---@field name? string
---@field path? string
---@field severity? string
---@field stop_column? integer
---@field stop_line? integer

---@class PyreflyOutput
---@field errors? PyreflyError[]

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
	if name == 'warn' or name == 'warning' then
		return diagnostic.severity.WARN
	end
	if name == 'info' or name == 'information' then
		return diagnostic.severity.INFO
	end
	return diagnostic.severity.HINT
end

---@param path? string
---@param context LintContext
---@return boolean
local function belongs_to_buffer(path, context)
	if path == nil or path == '' then
		return true
	end
	---@type string
	local buffer_filename = vim.fs.normalize(context.filename) or context.filename
	---@type string
	local candidate
	if path:sub(1, 1) == '/' then
		candidate = vim.fs.normalize(path) or path
	else
		local joined = vim.fs.joinpath(context.root, path)
		candidate = vim.fs.normalize(joined) or joined
	end
	return candidate == buffer_filename or vim.fs.basename(candidate) == vim.fs.basename(buffer_filename)
end

---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
	if vim.trim(output) == '' then
		return {}
	end
	if type(context) ~= 'table' then
		error('pyrefly parser requires a LintContext', 0)
	end

	local ok, decoded = pcall(vim.json.decode, output)
	if not ok or type(decoded) ~= 'table' then
		error(('invalid Pyrefly JSON: %s'):format(vim.trim(output)), 0)
	end

	---@cast context LintContext
	---@cast decoded PyreflyOutput
	local diagnostics = {}
	for _, record in ipairs(decoded.errors or {}) do
		if type(record) == 'table' and belongs_to_buffer(record.path, context) then
			local start_line = math.max(integer(record.line, 1) - 1, 0)
			local start_column = math.max(integer(record.column, 1) - 1, 0)
			local end_line = math.max(integer(record.stop_line, start_line + 1) - 1, start_line)
			local minimum_end_column = end_line == start_line and start_column + 1 or 0
			local end_column = math.max(integer(record.stop_column, minimum_end_column + 1) - 1, minimum_end_column)
			local name = tostring(record.name or '')
			local message = tostring(record.description or record.concise_description or 'Unknown Pyrefly diagnostic')
			if name ~= '' then
				message = ('[%s] %s'):format(name, message)
			end
			diagnostics[#diagnostics + 1] = {
				lnum = start_line,
				end_lnum = end_line,
				col = start_column,
				end_col = end_column,
				message = message,
				severity = severity(record.severity),
				source = 'pyrefly',
				code = name ~= '' and name or record.code,
			}
		end
	end
	return diagnostics
end

return ---@type Linter
{
	automatic = false,
	cmd = 'pyrefly',
	args = function(context)
		return {
			'check',
			'--output-format=json',
			'--summary=none',
			context.filename,
		}
	end,
	append_fname = false,
	cwd = function(context)
		return context.root
	end,
	exit_codes = {
		[0] = true,
		[1] = true,
	},
	parser = parse,
	root_markers = {
		'pyrefly.toml',
		'pyproject.toml',
		'.git',
	},
	stdin = false,
	stream = 'stdout',
	timeout = 60000,
}
