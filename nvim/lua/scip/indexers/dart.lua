-- #################################################################
-- /qompassai/lua/scip/indexers/dart.lua
-- Qompass AI SCIP Dart Indexer
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

---Arguments used to invoke the globally installed scip_dart package.
---
---The final `.` instructs scip_dart to index the project represented by the
---SCIP context's working directory.
---
---@type string[]
local args = {
	'pub',
	'global',
	'run',
	'scip_dart',
	'.',
}

---@type ScipIndexer
local indexer = {
	args = args,
	command = 'dart',
	filetypes = {
		dart = true,
	},
	markers = {
		'.git',
		'analysis_options.yaml',
		'pubspec.yaml',
	},
}

return indexer
