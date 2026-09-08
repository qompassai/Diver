-- /qompassai/lua/linters/markdownlint.lua
-- Qompass AI Markdownlint
-- SPDX-License-Identifier: Apache-2.0
return ---@type vim.lint.Config
{
	cmd = 'markdownlint',
	stdin = false,
	append_fname = true,
	args = {
		'--format',
		'json',
	},
	stream = 'stdout',
	ignore_exitcode = true,
	parser = function(output, _)
		local ok, decoded = pcall(vim.json.decode, output)
		if not ok or type(decoded) ~= 'table' then
			return {}
		end

		local diagnostics = {}

		for _, item in ipairs(decoded) do
			local line = item.lineNumber or item.line or 1
			local col = item.ruleInformation and item.ruleInformation.column or 1
			diagnostics[#diagnostics + 1] = {
				lnum = math.max(line - 1, 0),
				col = math.max(col - 1, 0),
				end_lnum = math.max(line - 1, 0),
				end_col = math.max(col, 0),
				severity = vim.diagnostic.severity.WARN,
				source = 'markdownlint',
				code = item.ruleNames and item.ruleNames[1] or 'markdownlint',
				message = item.errorDetail
					or item.ruleDescription
					or item.errorContext
					or (item.ruleNames and table.concat(item.ruleNames, '/'))
					or 'Markdownlint error',
			}
		end
		return diagnostics
	end,
}
