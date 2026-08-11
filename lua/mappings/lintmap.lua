-- /qompassai/Diver/lua/mappings/lintmap.lua
-- Qompass AI Diver Linter Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
---@module 'mappings.lintmap'
local M = {}
function M.setup_lintmap()
	if M.configured then
		return
	end
	M.configured = true
	vim.keymap.set('n', '<leader>cd', function()
		vim.diagnostic.reset(nil, 0)
	end, {
		desc = 'Diagnostics: clear current buffer',
		silent = true,
	})
end
return M
