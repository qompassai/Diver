-- /qompassai/Diver/lua/mappings/source.lua
-- Qompass AI Diver Source Mappings
-- Copyright (C) 2025 Qompass AI, All rights reserved
-- --------------------------------------------------
local M = {}
function M.setup()
	local _ = require('mason-core.functional')
	local Optional = require('mason-core.optional')
	local null_ls_to_package = {
		['cmake_lint'] = 'cmakelint',
		['cmake_format'] = 'cmakelang',
		['eslint_d'] = 'eslint_d',
		['goimports_reviser'] = 'goimports_reviser',
		['phpcsfixer'] = 'php-cs-fixer',
		['verible_verilog_format'] = 'verible',
		['lua_format'] = 'luaformatter',
		['deno_fmt'] = 'deno',
		['ruff_format'] = 'ruff',
		['xmlformat'] = 'xmlformatter'
	}
	local package_to_null_ls = _.invert(null_ls_to_package)
	---@param source string: Source Name from NullLs
	---@return string: Package Name from Mason
	M.getPackageFromNullLs = _.memoize(function(source)
		return Optional.of_nilable(null_ls_to_package[source]):or_else_get(
			_.always(source:gsub('%_', '-')))
	end)
	---@param package string: Package Name from Mason
	---@return string: NullLs Source Name
	M.getNullLsFromPackage = _.memoize(function(package)
		return Optional.of_nilable(package_to_null_ls[package]):or_else_get(
			_.always(package:gsub('%-', '_')))
	end)
end

return M
