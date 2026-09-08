-- #################################################################
-- /qompassai/lua/linters/nix.lua
-- Qompass AI Nix
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
-- /qompassai/lua/scip/indexers/nix.lua
-- Qompass AI SCIP Nix Indexer
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

---Native SCIP indexer definition for the Nix language.
---
---No verified Nix-language SCIP generator is currently available as a
---standard SCIP indexer. The fact that parts of the SCIP ecosystem use Nix
---for packaging/build infrastructure does not imply that they index Nix
---source code.
---
---This entry remains disabled until a compatible external `scip-nix`
---executable is installed or implemented.
---@type ScipIndexer
local indexer = {
	args = {
		'index',
		'.',
	},

	command = 'scip-nix',

	enabled = false,

	filetypes = {
		nix = true,
	},

	markers = {
		'.git',
		'default.nix',
		'flake.lock',
		'flake.nix',
		'shell.nix',
	},
}

return indexer
