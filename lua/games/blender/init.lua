-- #################################################################
-- /qompassai/Diver/lua/games/blender/init.lua
-- Qompass AI Blender Native Tooling
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
-- Native Blender tooling: headless still/turntable rendering,
-- glTF/FBX export, sprite-sheet baking with a JSON manifest, and
-- batch runs over .blend directories -- all through `blender -b`,
-- no plugin. (Engine wiring into games/init.lua happens in a later
-- integration pass; see the track report for the snippet.)
local M = {}

M.config = require('games.blender.config')
M.versions = require('games.blender.versions')
M.render = require('games.blender.render')
M.export = require('games.blender.export')
M.sprites = require('games.blender.sprites')
M.batch = require('games.blender.batch')
M.actions = require('games.blender.actions')
M.commands = require('games.blender.commands')
M.health = require('games.blender.health')

function M.setup()
    M.commands.setup()
end

M.show_menu = M.actions.show_menu
M.run_action_by_id = M.actions.run_action_by_id

return M
