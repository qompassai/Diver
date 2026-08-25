-- #################################################################
-- /qompassai/lua/linters/oxlint.lua
-- Qompass AI Oxlint
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
-- /qompassai/Diver/lua/linters/oxlint.lua
-- Qompass AI Diver Native Oxlint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local api = vim.api
local diagnostic = vim.diagnostic
local fn = vim.fn

---@class OxlintSpan
---@field column? integer One-based byte column.
---@field length? integer Byte length.
---@field line? integer One-based line.
---@field offset? integer Zero-based byte offset.

---@class OxlintLabel
---@field span? OxlintSpan

---@class OxlintDiagnostic
---@field causes? table[]
---@field code? string
---@field filename? string
---@field help? string
---@field labels? OxlintLabel[]
---@field message? string
---@field related? table[]
---@field severity? string
---@field url? string

---@class OxlintReport
---@field diagnostics? OxlintDiagnostic[]

---@param value unknown
---@param fallback integer
---@return integer
local function integer(value, fallback)
	if type(value) == 'number' then
		return fn.float2nr(value)
	end
	if type(value) == 'string' then
		return fn.str2nr(value, 10)
	end
	return fallback
end

---@param value unknown
---@return integer
local function severity(value)
	local name = tostring(value or ''):lower()
	if name == 'error' then
		return diagnostic.severity.ERROR
	end
	if name == 'advice' or name == 'information' or name == 'info' then
		return diagnostic.severity.INFO
	end
	if name == 'help' or name == 'hint' then
		return diagnostic.severity.HINT
	end
	return diagnostic.severity.WARN
end

---@param bufnr integer
---@param start_line integer
---@param start_column integer
---@param length integer
---@return integer end_line
---@return integer end_column
local function advance_position(bufnr, start_line, start_column, length)
	local line_count = math.max(api.nvim_buf_line_count(bufnr), 1)
	local row = math.min(math.max(start_line, 0), line_count - 1)
	local column = math.max(start_column, 0)
	local remaining = math.max(length, 1)

	while remaining > 0 and row < line_count do
		local text = api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1] or ''
		column = math.min(column, #text)
		local available = #text - column

		if remaining <= available then
			return row, column + remaining
		end

		remaining = remaining - available
		if row == line_count - 1 then
			return row, #text
		end

		-- Account for the newline separating adjacent buffer lines.
		remaining = remaining - 1
		row = row + 1
		column = 0
	end

	return row, column
end

---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, context)
	if vim.trim(output) == '' then
		return {}
	end

	local ok, decoded = pcall(vim.json.decode, output)
	if not ok or type(decoded) ~= 'table' then
		error(('invalid Oxlint JSON: %s'):format(vim.trim(output)), 0)
	end

	---@cast decoded OxlintReport
	local records = type(decoded.diagnostics) == 'table' and decoded.diagnostics or {}
	local diagnostics = {}

	for _, record in ipairs(records) do
		if type(record) == 'table' then
			local labels = type(record.labels) == 'table' and record.labels or {}
			local primary = type(labels[1]) == 'table' and labels[1] or {}
			local span = type(primary.span) == 'table' and primary.span or {}
			local lnum = math.max(integer(span.line, 1) - 1, 0)
			local col = math.max(integer(span.column, 1) - 1, 0)
			local length = math.max(integer(span.length, 1), 1)
			local end_lnum, end_col = advance_position(context.bufnr, lnum, col, length)
			local code = tostring(record.code or 'oxlint')
			local message = tostring(record.message or 'Unknown Oxlint diagnostic')
			local help = tostring(record.help or '')
			if help ~= '' then
				message = message .. '\n' .. help
			end

			diagnostics[#diagnostics + 1] = {
				lnum = lnum,
				end_lnum = end_lnum,
				col = col,
				end_col = end_col,
				message = ('[%s] %s'):format(code, message),
				severity = severity(record.severity),
				source = 'oxlint',
				code = code,
				user_data = {
					url = record.url,
				},
			}
		end
	end

	return diagnostics
end

return ---@type Linter
{
	cmd = 'oxlint',
	args = {
		'--format',
		'json',
		'--no-error-on-unmatched-pattern',
	},
	append_fname = true,
	cwd = function(context)
		return context.root
	end,
	exit_codes = {
		[0] = true,
		[1] = true,
	},
	parser = parse,
	stdin = false,
	stream = 'stdout',
	timeout = 30000,
}
