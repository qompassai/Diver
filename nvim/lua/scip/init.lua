-- #################################################################
-- /qompassai/lua/scip/init.lua
-- Qompass AI SCIP Init
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
local config = require('scip.config')
local health = require('scip.health')
local index = require('scip.index')
local registry = require('scip.registry')
local ui = require('scip.ui')
local M = {}
M.cancel = index.cancel
M.coverage = ui.coverage
M.health = health.check
M.index = index.run
M.lint = index.lint
M.print = index.print
M.register = registry.register
M.snapshot = index.snapshot
M.stats = index.stats
M.status = index.status
---@param opts? ScipConfigOpts
function M.setup(opts)
	config.setup(opts)
	ui.setup_commands()
end

return M
