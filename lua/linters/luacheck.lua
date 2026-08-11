-- #################################################################
-- /qompassai/lua/linters/luacheck.lua
-- Qompass AI Luacheck
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
local fn = vim.fn
---@param value string
---@return integer
local function decimal(value)
	return fn.str2nr(value, 10)
end
---@param code string
---@return vim.diagnostic.Severity
local function severity(code)
	if code:sub(1, 1) == 'E' then
		return diagnostic.severity.ERROR
	end
	return diagnostic.severity.WARN
end
---@param output string
---@param context LintContext
---@return vim.Diagnostic.Set[]
local function parse(output, context)
	local diagnostics = {}
	if output == '' then
		return diagnostics
	end

	local target = vim.fs.normalize(context.filename) or context.filename
	local target_basename = vim.fs.basename(target)

	for line in
		vim.gsplit(output, '\n', {
			plain = true,
			trimempty = true,
		})
	do
		local path, line_number, start_column, end_column, code, message =
			line:match('^%s*(.-):(%d+):(%d+)%-(%d+):%s*%(([EW]%d%d%d)%)%s*(.-)%s*$')

		if not path then
			path, line_number, start_column, code, message =
				line:match('^%s*(.-):(%d+):(%d+):%s*%(([EW]%d%d%d)%)%s*(.-)%s*$')
			end_column = start_column
		end

		if path and line_number and start_column and end_column and code and message and message ~= '' then
			local normalized_path = vim.fs.normalize(path) or path
			local matches_target = normalized_path == target or vim.fs.basename(normalized_path) == target_basename

			if matches_target then
				local lnum = math.max(decimal(line_number) - 1, 0)
				local col = math.max(decimal(start_column) - 1, 0)
				-- Luacheck reports an inclusive, one-based end column. Neovim
				-- expects an exclusive, zero-based end column, so the numeric
				-- Luacheck end column is already the correct converted value.
				local end_col = math.max(decimal(end_column), col + 1)

				diagnostics[#diagnostics + 1] = {
					lnum = lnum,
					end_lnum = lnum,
					col = col,
					end_col = end_col,
					message = ('[%s] %s'):format(code, message),
					severity = severity(code),
					source = 'luacheck',
					code = code,
				}
			end
		end
	end

	return diagnostics
end

return ---@type Linter
{
	cmd = 'luacheck',
	args = function(context)
		return {
			'--formatter',
			'plain',
			'--codes',
			'--ranges',
			'--no-color',
			'--no-cache',
			'--std',
			'luajit',
			'--read-globals',
			'vim',
			'--filename',
			context.filename,
			'-',
		}
	end,
	append_fname = false,
	cwd = function(context)
		return vim.fs.dirname(context.filename) or context.cwd
	end,
	exit_codes = {
		[0] = true,
		[1] = true,
		[2] = true,
	},
	parser = parse,
	stdin = true,
	stream = 'stdout',
	timeout = 15000,
}
