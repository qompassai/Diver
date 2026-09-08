-- #################################################################
-- /qompassai/Diver/lua/utils/games/unreal/init.lua
-- Qompass AI Unreal Native Tooling
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
local M = {}

M.config = require('utils.games.unreal.config')
M.util = require('utils.games.unreal.util')
M.actions = require('utils.games.unreal.actions')
M.commands = require('utils.games.unreal.commands')
function M.setup()
  M.commands.setup()
end

M.show_menu = M.actions.show_menu
M.run_action_by_id = M.actions.run_action_by_id

return M
