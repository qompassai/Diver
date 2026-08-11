-- #################################################################
-- /qompassai/lua/linters/checkpatch.lua
-- Qompass AI Checkpatch
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
-- /qompassai/Diver/lua/linters/checkpatch.lua
-- Qompass AI Diver Native Linux Checkpatch Linter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic

local severities = {
	CHECK = diagnostic.severity.INFO,
	ERROR = diagnostic.severity.ERROR,
	WARNING = diagnostic.severity.WARN,
}

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
		local path, lnum, column, level, code, message = line:match('^(.-):(%d+):(%d+):%s*(%u+):%s*([%u%d_]+):%s*(.+)$')
		if path == nil then
			path, lnum, level, code, message = line:match('^(.-):(%d+):%s*(%u+):%s*([%u%d_]+):%s*(.+)$')
		end
		if path == nil then
			path, lnum, level, message = line:match('^(.-):(%d+):%s*(%u+):%s*(.+)$')
		end
		if path ~= nil and lnum ~= nil and level ~= nil and message ~= nil then
			local line_number = math.max(integer(lnum, 1) - 1, 0)
			local start_column = math.max(integer(column, 1) - 1, 0)
			diagnostics[#diagnostics + 1] = {
				lnum = line_number,
				end_lnum = line_number,
				col = start_column,
				end_col = start_column + 1,
				message = code ~= nil and ('[%s] %s'):format(code, message) or message,
				severity = severities[level] or diagnostic.severity.WARN,
				source = 'checkpatch',
				code = code,
			}
		end
	end
	return diagnostics
end

return ---@type Linter
{
	cmd = {
		'checkpatch.pl',
		'checkpatch',
	},
	args = {
		'--no-tree',
		'--file',
		'--strict',
		'--terse',
		'--show-types',
		'--no-summary',
		'--color=never',
	},
	append_fname = true,
	automatic = false,
	cwd = function(context)
		return vim.fs.dirname(context.filename) or context.cwd
	end,
	ignore_exitcode = true,
	parser = parse,
	stdin = false,
	stream = 'stdout',
	timeout = 30000,
}
