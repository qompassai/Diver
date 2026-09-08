-- /qompassai/Diver/lua/mappings/init.lua
-- Qompass AI Diver Mappings Module
-- Copyright (C) 2025 Qompass AI, All rights reserved
-----------------------------------------------------
---@module 'mappings.init'
local M = {}
local mapping_modules = {
	'aimap',
	'cicdmap',
	'datamap',
	'ddxmap',
	'disable',
	'genmap',
	'langmap',
	'lspmap',
	'lintmap',
	'utilmap',
	'navmap',
}
---@param message string
local function warn(message)
	vim.notify(message, vim.log.levels.WARN, {
		title = 'Mapping setup',
	})
end
function M.setup()
	for _, name in ipairs(mapping_modules) do
		local ok, module_or_error = pcall(require, 'mappings.' .. name)
		if not ok then
			warn(('Failed to load mappings.%s: %s'):format(name, tostring(module_or_error)))
		else
			local module = module_or_error
			local setup_name = 'setup_' .. name
			local setup = module[setup_name] or module.setup
			if type(setup) ~= 'function' then
				warn(('mappings.%s has no %s() or setup() function'):format(name, setup_name))
			else
				local setup_ok, setup_error = pcall(setup)
				if not setup_ok then
					warn(('Failed to configure mappings.%s: %s'):format(name, tostring(setup_error)))
				end
			end
		end
	end
end
return M
