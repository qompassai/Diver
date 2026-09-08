-- #################################################################
-- /qompassai/lua/linters/markdown-table-formatter.lua
-- Qompass AI Markdown Table Formatter
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
-- /qompassai/Diver/lua/linters/markdown-table-formatter.lua
-- Qompass AI Diver Native Markdown Table Formatter Check
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
---@param context LintContext
---@return integer, integer
local function first_table(context)
	for index, line in ipairs(vim.api.nvim_buf_get_lines(context.bufnr, 0, -1, false)) do
		local start = line:find('|', 1, true)
		if start ~= nil and line:find('|', start + 1, true) ~= nil then
			return index - 1, start - 1
		end
	end
	return 0, 0
end
---@param output string
---@param context LintContext|integer
---@return vim.Diagnostic.Set[]
local function parse(output, context)
	local clean = vim.trim(output:gsub('\27%[[%d;]*m', ''))
	if not clean:match('files? contain markdown tables? to format') then
		return {}
	end
	if type(context) ~= 'table' then
		error('markdown-table-formatter parser requires a LintContext', 0)
	end
	---@cast context LintContext
	local lnum, col = first_table(context)
	return {
		{
			lnum = lnum,
			end_lnum = lnum,
			col = col,
			end_col = col + 1,
			message = 'Markdown table formatting differs from markdown-table-formatter output',
			severity = vim.diagnostic.severity.WARN,
			source = 'markdown-table-formatter',
			code = 'table-format',
		},
	}
end

return ---@type Linter
{
	cmd = 'markdown-table-formatter',
	args = {
		'--check',
	},
	append_fname = true,
	automatic = false,
	cwd = function(context)
		return vim.fs.dirname(context.filename) or context.cwd
	end,
	exit_codes = {
		[0] = true,
	},
	parser = parse,
	root_markers = {
		'package.json',
		'.git',
	},
	stdin = false,
	stream = 'stdout',
	timeout = 30000,
}
