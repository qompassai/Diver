-- #################################################################
-- /qompassai/Diver/lua/linters/checkbashisms.lua
-- Qompass AI Diver Native Checkbashisms Linter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
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

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
	local diagnostics = {}
	for line in vim.gsplit(output, '\n', { plain = true, trimempty = true }) do
		local _, lnum, column, message = line:match('^(.-):(%d+):(%d+):%s*warning:%s*possible bashism;%s*(.+)$')
		if lnum ~= nil and message ~= nil then
			local line_number = math.max(integer(lnum, 1) - 1, 0)
			local start_column = math.max(integer(column, 1) - 1, 0)
			diagnostics[#diagnostics + 1] = {
				lnum = line_number,
				end_lnum = line_number,
				col = start_column,
				end_col = start_column + 1,
				message = message,
				severity = vim.diagnostic.severity.WARN,
				source = 'checkbashisms',
				code = 'possible-bashism',
			}
		end
	end
	return diagnostics
end

return ---@type Linter
{
	cmd = {
		'checkbashisms',
		'checkbashisms.pl',
	},
	args = {
		'--lint',
	},
	append_fname = true,
	cwd = function(context)
		return vim.fs.dirname(context.filename) or context.cwd
	end,
	ignore_exitcode = true,
	parser = parse,
	stdin = false,
	stream = 'stdout',
	timeout = 30000,
}
