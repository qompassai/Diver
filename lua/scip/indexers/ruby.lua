-- #################################################################
-- /qompassai/lua/scip/indexers/ruby.lua
-- Qompass AI SCIP Ruby Indexer
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
local fs = vim.fs
local utils = require('scip.utils')
---Build scip-ruby arguments for the current project.
---
---Projects containing `sorbet/config` already provide Sorbet's input paths and
---configuration, so no explicit project path is needed.
---
---Projects without `sorbet/config` fall back to indexing the current project
---directory using `.`.
---
---@param context ScipContext SCIP indexing context.
---@return string[] args Arguments passed to scip-ruby.
local function args(context)
	local sorbet_config = fs.joinpath(context.root, 'sorbet', 'config')

	if utils.path_exists(sorbet_config) then
		return {}
	end

	return {
		'.',
	}
end

---@type ScipIndexer
local indexer = {
	args = args,
	command = 'scip-ruby',

	filetypes = {
		ruby = true,
	},
	markers = {
		'.git',
		'.ruby-version',
		'Gemfile',
		'Gemfile.lock',
		'Rakefile',
		'sorbet',
	},
}

return indexer
