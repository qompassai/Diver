-- #################################################################
-- /qompassai/lua/scip/indexers/dotnet.lua
-- Qompass AI Dotnet
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
-- /qompassai/lua/scip/indexers/dotnet.lua
-- Qompass AI SCIP .NET Indexer
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

---@type ScipIndexer
local indexer = {
	args = {
		'index',
	},
	command = 'scip-dotnet',
	filetypes = {
		cs = true,
		fsharp = true,
		vb = true,
	},
	markers = {
		'.git',
		'Directory.Build.props',
		'Directory.Build.targets',
		'Directory.Packages.props',
		'global.json',
	},
}

return indexer
