-- #################################################################
-- /qompassai/lua/utils/bsp/commands.lua
-- Qompass AI BSP Util Commands
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
local api = vim.api
local M = {}
---@class QompassBspModule
---@field compile fun(root?: string)
---@field info fun(root?: string)
---@field reload fun(root?: string)
---@field restart fun(bufnr?: integer)
---@field start fun(bufnr?: integer)
---@field stop fun(root?: string)
---@field targets fun(root?: string)

---@param bsp QompassBspModule
function M.setup(bsp)
	api.nvim_create_user_command('BspCompile', function()
		bsp.compile()
	end, {
		desc = 'Compile all discovered BSP targets',
		force = true,
	})

	api.nvim_create_user_command('BspInfo', function()
		bsp.info()
	end, {
		desc = 'Show the current BSP session',
		force = true,
	})

	api.nvim_create_user_command('BspReload', function()
		bsp.reload()
	end, {
		desc = 'Reload the current BSP workspace',
		force = true,
	})

	api.nvim_create_user_command('BspRestart', function()
		bsp.restart()
	end, {
		desc = 'Restart the current BSP server',
		force = true,
	})

	api.nvim_create_user_command('BspStart', function()
		bsp.start()
	end, {
		desc = 'Start the current project BSP server',
		force = true,
	})

	api.nvim_create_user_command('BspStop', function()
		bsp.stop()
	end, {
		desc = 'Stop the current project BSP server',
		force = true,
	})

	api.nvim_create_user_command('BspTargets', function()
		bsp.targets()
	end, {
		desc = 'Show BSP build targets',
		force = true,
	})
end

return M
