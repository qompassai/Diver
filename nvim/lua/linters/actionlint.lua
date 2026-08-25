-- /qompassai/Diver/lua/linters/actionlint.lua
-- Qompass AI Actionlint Linter Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
---@type vim.lint.Config
local actionlint = {
	name = 'actionlint',
	cmd = 'actionlint',
	stdin = true,
	append_fname = false,
	args = function(context)
		return {
			'-format',
			'{{json .}}',
			'-stdin-filename',
			context.filename,
			'-',
		}
	end,
	stream = 'stdout',
	ignore_exitcode = true,
	parser = function(output, _)
		---@type vim.Diagnostic.Set[]
		local diagnostics = {}
		if output == '' then
			return diagnostics
		end
		local ok, decoded = pcall(vim.json.decode, output)
		if not ok or type(decoded) ~= 'table' then
			return diagnostics
		end
		for _, item in ipairs(decoded) do
			diagnostics[#diagnostics + 1] = {
				lnum = math.max(item.line - 1, 0),
				end_lnum = math.max(item.line - 1, 0),
				col = math.max(item.column - 1, 0),
				end_col = item.end_column or item.column,
				severity = vim.diagnostic.severity.WARN,
				source = 'actionlint: ' .. item.kind,
				message = item.message,
			}
		end
		return diagnostics
	end,
}
return actionlint
