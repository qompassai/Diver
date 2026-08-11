-- #################################################################
-- /qompassai/lua/scip/indexers/go.lua
-- Qompass AI Go
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
-- /qompassai/lua/scip/indexers/go.lua
-- Qompass AI SCIP Go Indexer
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

---scip-go discovers the Go module or workspace from its working directory,
---so no additional command-line arguments are required.
---@type string[]
local args = {}

---@type ScipIndexer
local indexer = {
	args = args,

	command = 'scip-go',

	filetypes = {
		go = true,
		gomod = true,
		gosum = true,
		gowork = true,
	},

	markers = {
		'.git',
		'go.mod',
		'go.work',
	},
}

return indexer
