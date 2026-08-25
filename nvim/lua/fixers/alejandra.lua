-- /qompassai/Diver/fixer/alejandra.lua
-- Qompass AI Alejandra Nix Fixer Spec
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- ----------------------------------------
return {
	append_fname = false,
	args = {},
	cmd = 'alejandra',
	ignore_exitcode = true,
	stdin = true,
	stream = 'stderr',
	parser = function(output)
		if output == '' then
			return {}
		end
		return {
			{
				col = 0,
				end_col = 0,
				end_lnum = 0,
				lnum = 0,
				message = output,
				severity = vim.diagnostic.severity.ERROR,
				source = 'alejandra',
			},
		}
	end,
}
