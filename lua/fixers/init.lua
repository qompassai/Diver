-- #################################################################
-- /qompassai/lua/fixers/init.lua
-- Qompass AI Init
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
local M = {}
local modules = {
	'alejandra',
	'blackd',
	'cookstyle',
	'css-beautify',
	'gofumpt',
	'goimports',
	'htmlbeautify',
	'phpcsfixer',
	'shellharden',
	'sql-formatter',
}
function M.setup()
	for _, name in ipairs(modules) do
		local module = require('fixers.' .. name)
		if type(module) == 'function' then
			module()
		elseif type(module) == 'table' and type(module.setup) == 'function' then
			module.setup()
		end
	end
end
return M
