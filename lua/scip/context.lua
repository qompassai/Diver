-- #################################################################
-- /qompassai/lua/scip/context.lua
-- Qompass AI Context
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
-- ################################################################# -- /qompassai/lua/scip/context.lua
-- -- Qompass AI SCIP Context
-- -- SPDX-License-Identifier: Apache-2.0
-- Copyright (c) 2026 Qompass AI --
local api = vim.api
local config = require('scip.config')
local M = {}
---Create a fully resolved context passed to an indexer.
---Keeping context construction here ensures command and argument callbacks
---always receive the same fields.
---@param name string
---@param bufnr integer
---@param root string
---@return QompassScipContext
function M.new(name, bufnr, root)
	root = vim.fs.normalize(root)
	return {
		bufnr = bufnr,
		filename = api.nvim_buf_get_name(bufnr),
		index_file = config.index_path(root),
		name = name,
		root = root,
	}
end
return M
