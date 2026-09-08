-- #################################################################
-- /qompassai/lua/linters/lua.lua
-- Qompass AI Lua
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
-- /qompassai/lua/scip/indexers/lua.lua
-- Qompass AI SCIP Lua Indexer
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

---Native SCIP indexer definition for Lua.
---
---There is currently no verified standard Lua SCIP indexer comparable to
---scip-go or scip-typescript. This definition is therefore disabled by
---default and serves as a registration point for a compatible external
---`scip-lua` executable.
---
---Enable this indexer only after installing or implementing a command that
---writes a valid SCIP index.
---@type ScipIndexer
local indexer = {
	args = {
		'index',
		'.',
	},

	command = 'scip-lua',

	enabled = false,

	filetypes = {
		lua = true,
	},

	markers = {
		'.git',
		'.luarc.json',
		'.luarc.jsonc',
		'lua',
		'rockspec',
	},
}

return indexer
