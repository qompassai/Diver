-- #################################################################
-- /qompassai/lua/scip/registry.lua
-- Qompass AI Diver SCIP Registry
-- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI
-- #################################################################

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
local config = require('scip.config')
local context = require('scip.context')
local root = require('scip.root')
local utils = require('scip.utils')
local M = {}
---@class ScipMatch
---@field command string
---@field context ScipContext
---@field indexer ScipIndexer
---@field name string

---Return an enabled indexer by name.
---@param name string
---@return ScipIndexer?
function M.get(name)
	local indexer = config.get().indexers[name]

	if indexer == nil or indexer.enabled == false then
		return nil
	end

	return indexer
end

---Return enabled indexer names in configured priority order.
---@return string[]
function M.names()
	local names = {}

	for _, name in ipairs(config.get().indexer_order) do
		if M.get(name) ~= nil then
			names[#names + 1] = name
		end
	end

	return names
end

---Return sorted filetypes supported by an indexer.
---@param indexer ScipIndexer
---@return string[]
function M.filetypes(indexer)
	local filetypes = {}

	for filetype, enabled in pairs(indexer.filetypes) do
		if enabled then
			filetypes[#filetypes + 1] = filetype
		end
	end

	table.sort(filetypes)

	return filetypes
end

---Determine whether an indexer matches a buffer's filetype and project.
---@param indexer ScipIndexer
---@param bufnr integer
---@return string?
function M.matching_root(indexer, bufnr)
	local filetype = vim.bo[bufnr].filetype

	if indexer.filetypes[filetype] ~= true then
		return nil
	end

	return root.find(bufnr, indexer.markers)
end

---Resolve a named indexer for a buffer.
---@param name string
---@param bufnr integer
---@param root_override? string
---@return ScipMatch?, string?
function M.resolve(name, bufnr, root_override)
	local indexer = M.get(name)

	if indexer == nil then
		return nil, 'Unknown or disabled SCIP indexer: ' .. name
	end

	local project_root

	if root_override ~= nil and root_override ~= '' then
		project_root = vim.fs.normalize(root_override)
	else
		project_root = root.resolve(bufnr, indexer.markers)
	end

	local ctx = context.new(name, bufnr, project_root)
	local command, command_error = utils.resolve_command(indexer.command, ctx)

	if command == nil then
		return nil, command_error
	end

	if not utils.executable(command) then
		return nil, 'SCIP indexer is not executable: ' .. command
	end

	return {
		command = command,
		context = ctx,
		indexer = indexer,
		name = name,
	}, nil
end

---Auto-detect the first ready indexer matching the current buffer.
---@param bufnr? integer
---@return ScipMatch?, string?
function M.detect(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()

	local missing = {}

	for _, name in ipairs(config.get().indexer_order) do
		local indexer = M.get(name)

		if indexer ~= nil then
			local project_root = M.matching_root(indexer, bufnr)

			if project_root ~= nil then
				local ctx = context.new(name, bufnr, project_root)
				local command, command_error = utils.resolve_command(indexer.command, ctx)

				if command ~= nil and utils.executable(command) then
					return {
						command = command,
						context = ctx,
						indexer = indexer,
						name = name,
					},
						nil
				end

				if command ~= nil then
					missing[#missing + 1] = command
				elseif command_error ~= nil then
					missing[#missing + 1] = command_error
				end
			end
		end
	end

	if #missing > 0 then
		return nil, 'Missing/unavailable SCIP indexer: ' .. table.concat(missing, ', ')
	end

	return nil, 'No configured SCIP indexer matches this buffer and project'
end

---Register or replace a native SCIP indexer.
---@param name string
---@param indexer ScipIndexer
function M.register(name, indexer)
	vim.validate('name', name, 'string')
	vim.validate('indexer', indexer, 'table')

	if name == '' then
		error('SCIP indexer name must not be empty')
	end

	if type(indexer.command) ~= 'string' and type(indexer.command) ~= 'function' then
		error('SCIP indexer command must be a string or function')
	end

	if type(indexer.args) ~= 'table' and type(indexer.args) ~= 'function' then
		error('SCIP indexer args must be a table or function')
	end

	if type(indexer.filetypes) ~= 'table' then
		error('SCIP indexer filetypes must be a table')
	end

	if type(indexer.markers) ~= 'table' then
		error('SCIP indexer markers must be a table')
	end

	local cfg = config.get()

	cfg.indexers[name] = vim.deepcopy(indexer)

	if not vim.tbl_contains(cfg.indexer_order, name) then
		cfg.indexer_order[#cfg.indexer_order + 1] = name
	end
end

return M
