-- #################################################################
-- /qompassai/lua/scip/health.lua
-- Qompass AI Health
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
-- #################################################################

local api = vim.api
local health = vim.health

local config = require('scip.config')
local context = require('scip.context')
local registry = require('scip.registry')
local root = require('scip.root')
local state = require('scip.state')
local utils = require('scip.utils')

local M = {}

---Report whether an executable is available.
---
---This is used for commands that are required independently of a specific
---language indexer, such as the main `scip` CLI.
---
---@param command string Executable name or path to check.
---@param label? string Human-readable command label.
---@return nil
local function check_executable(command, label)
	local display_name = label or command

	if utils.executable(command) then
		health.ok(('%s: %s'):format(display_name, command))
		return
	end

	health.warn(('%s not found: %s'):format(display_name, command))
end

---Check all enabled SCIP indexers.
---
---Each configured indexer is resolved against the current buffer and project.
---Dynamic commands, such as a project-local `scip-php`, are resolved before
---their executability is checked.
---
---@param bufnr integer Buffer used to resolve project roots and indexers.
---@return nil
local function check_indexers(bufnr)
	health.start('Configured SCIP indexers')

	for _, name in ipairs(registry.names()) do
		local indexer = registry.get(name)

		if indexer ~= nil then
			local project_root = root.resolve(bufnr, indexer.markers)

			local ctx = context.new(name, bufnr, project_root)

			local command, resolve_error = utils.resolve_command(indexer.command, ctx)

			if command == nil then
				health.error(('%s: %s'):format(name, resolve_error or 'invalid command'))
			elseif utils.executable(command) then
				health.ok(('%s: %s'):format(name, command))
			else
				health.warn(('%s: missing %s'):format(name, command))
			end
		end
	end
end

---Check the SCIP state of the current project.
---
---Reports the resolved project root, configured index path, current filetype,
---whether an index already exists, and whether an indexer can be detected for
---the current buffer.
---
---@param bufnr integer Buffer used for project and indexer detection.
---@return nil
local function check_project(bufnr)
	health.start('Current SCIP project')

	local project_root = root.resolve(bufnr)
	local index_file = config.index_path(project_root)
	local filetype = vim.bo[bufnr].filetype

	health.info('root: ' .. project_root)
	health.info('index: ' .. index_file)
	health.info('filetype: ' .. (filetype ~= '' and filetype or '<none>'))

	if utils.path_exists(index_file) then
		health.ok('SCIP index exists')
	else
		health.warn('SCIP index does not exist')
	end

	local match, detect_error = registry.detect(bufnr)

	if match ~= nil then
		health.ok(('matching indexer: %s (%s)'):format(match.name, match.command))
		return
	end

	local message = 'matching indexer: none'

	if detect_error ~= nil and detect_error ~= '' then
		message = ('%s (%s)'):format(message, detect_error)
	end

	health.info(message)
end

---Check the active asynchronous SCIP indexer state.
---
---When an indexer is running, this reports its name, root, and elapsed
---execution time. Otherwise, it confirms that no indexing process is active.
---
---@return nil
local function check_state()
	health.start('SCIP process state')

	if not state.running() then
		health.ok('No SCIP indexer process is currently running')
		return
	end

	health.info('indexer: ' .. (state.current.indexer or '<unknown>'))

	health.info('root: ' .. (state.current.root or '<unknown>'))

	health.info(('elapsed: %.1f seconds'):format(state.elapsed()))
end

---Run all native SCIP health checks.
---
---The module follows Neovim's standard health-provider convention:
---
---    lua/scip/health.lua
---
---which allows it to be invoked through:
---
---    :checkhealth scip
---
---It can also be called directly by the native `:ScipHealth` command.
---
---@return nil
function M.check()
	local bufnr = api.nvim_get_current_buf()

	health.start('Qompass AI SCIP')

	check_executable('scip', 'SCIP CLI')

	check_indexers(bufnr)
	check_project(bufnr)
	check_state()
end

return M
