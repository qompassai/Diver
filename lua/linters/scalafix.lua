-- #################################################################
-- /qompassai/lua/scip/scalafix.lua
-- Qompass AI Diver Native Scalafix Linter
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
-- /qompassai/Diver/lua/linters/scalafix.lua

-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
local diagnostic = vim.diagnostic
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
---@param value? string
---@return integer
local function severity(value)
	local name = tostring(value or ''):lower()
	if name == 'error' then
		return diagnostic.severity.ERROR
	end
	if name == 'info' or name == 'information' then
		return diagnostic.severity.INFO
	end
	return diagnostic.severity.WARN
end

---@param output string
---@param _context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, _context)
	local diagnostics = {}
	for raw_line in
		vim.gsplit(output:gsub('\27%[[%d;]*m', ''), '\n', {
			plain = true,
			trimempty = true,
		})
	do
		local _, lnum, column, level, message = raw_line:match('^(.*):(%d+):(%d+):%s*(%a+):%s*(.+)$')
		if lnum == nil then
			_, lnum, level, message = raw_line:match('^(.*):(%d+):%s*(%a+):%s*(.+)$')
			column = '1'
		end
		if lnum ~= nil and message ~= nil then
			local start_line = math.max(integer(lnum, 1) - 1, 0)
			local start_column = math.max(integer(column, 1) - 1, 0)
			local rule = message:match('%[([^%]]+)%]%s*$')
			diagnostics[#diagnostics + 1] = {
				lnum = start_line,
				end_lnum = start_line,
				col = start_column,
				end_col = start_column + 1,
				message = vim.trim(message),
				severity = severity(level),
				source = 'scalafix',
				code = rule,
			}
		end
	end

	if #diagnostics == 0 then
		local detail = vim.trim(output:gsub('\27%[[%d;]*m', ''))
		if
			detail ~= ''
			and (detail:lower():find('error', 1, true) or detail:lower():find('would be changed', 1, true))
		then
			diagnostics[1] = {
				lnum = 0,
				end_lnum = 0,
				col = 0,
				end_col = 1,
				message = detail,
				severity = diagnostic.severity.ERROR,
				source = 'scalafix',
			}
		end
	end
	return diagnostics
end

return ---@type Linter
{
	cmd = 'scalafix',
	args = function(context)
		return {
			'--check',
			'--files',
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
	parser = parse,
	root_markers = {
		'.scalafix.conf',
		'build.sbt',
		'project',
		'.git',
	},
	stdin = false,
	stream = 'both',
	timeout = 120000,
}
