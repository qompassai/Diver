-- /qompassai/lua/scip/root.lua
-- Qompass AI SCIP Root
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
local fn = vim.fn

local config = require('scip.config')

local M = {}

---Find a SCIP project root for a buffer.
---
---This function does not fall back to Neovim's current working directory.
---If none of the supplied markers can be found, nil is returned.
---
---@param bufnr? integer Buffer to inspect. Defaults to the current buffer.
---@param markers? string[] Root markers to search for.
---@return string? root Normalized project root, or nil when none is found.
function M.find(bufnr, markers)
	local target_bufnr = bufnr or api.nvim_get_current_buf()
	local root_markers = markers or config.get().root_markers

	local found = vim.fs.root(target_bufnr, root_markers)

	if found == nil then
		return nil
	end

	return vim.fs.normalize(found)
end

---Resolve a SCIP project root for a buffer.
---
---Resolution order:
---
---1. Search using explicitly supplied markers.
---2. Search using the globally configured SCIP root markers.
---3. Fall back to Neovim's current working directory.
---
---@param bufnr? integer Buffer to inspect. Defaults to the current buffer.
---@param markers? string[] Preferred root markers.
---@return string root Normalized project root.
function M.resolve(bufnr, markers)
	local target_bufnr = bufnr or api.nvim_get_current_buf()

	if markers ~= nil then
		local marked_root = M.find(target_bufnr, markers)

		if marked_root ~= nil then
			return marked_root
		end
	end

	local configured_root = M.find(target_bufnr, config.get().root_markers)

	if configured_root ~= nil then
		return configured_root
	end

	return vim.fs.normalize(fn.getcwd())
end

return M
