-- #################################################################
-- /qompassai/lua/linters/cppcheck.lua
-- Qompass AI Cppcheck
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
-- /qompassai/Diver/lua/linters/cppcheck.lua
-- Qompass AI Diver Native Cppcheck Linter
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0

local diagnostic = vim.diagnostic

local severities = {
	debug = diagnostic.severity.HINT,
	error = diagnostic.severity.ERROR,
	information = diagnostic.severity.INFO,
	performance = diagnostic.severity.INFO,
	portability = diagnostic.severity.INFO,
	style = diagnostic.severity.INFO,
	warning = diagnostic.severity.WARN,
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
		local _, lnum, column, level, code, message = line:match('^(.-):(%d+):(%d+):([^:]+):([^:]+):(.+)$')
		if lnum ~= nil and level ~= nil and message ~= nil then
			local line_number = math.max(integer(lnum, 1) - 1, 0)
			local start_column = math.max(integer(column, 1) - 1, 0)
			level = vim.trim(level):lower()
			code = vim.trim(code or '')
			message = vim.trim(message)
			diagnostics[#diagnostics + 1] = {
				lnum = line_number,
				end_lnum = line_number,
				col = start_column,
				end_col = start_column + 1,
				message = code ~= '' and ('[%s] %s'):format(code, message) or message,
				severity = severities[level] or diagnostic.severity.WARN,
				source = 'cppcheck',
				code = code ~= '' and code or nil,
			}
		end
	end
	return diagnostics
end

return ---@type Linter
{
	cmd = 'cppcheck',
	args = {
		'--enable=warning,style,performance,portability',
		'--inline-suppr',
		'--quiet',
		'--template={file}:{line}:{column}:{severity}:{id}:{message}',
	},
	append_fname = true,
	cwd = function(context)
		return context.root
	end,
	exit_codes = {
		[0] = true,
	},
	parser = parse,
	root_markers = {
		'compile_commands.json',
		'CMakeLists.txt',
		'meson.build',
		'.git',
	},
	stdin = false,
	stream = 'stderr',
	timeout = 60000,
}
