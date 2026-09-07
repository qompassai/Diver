-- #################################################################
-- /qompassai/Diver/lua/utils/games/godot/init.lua
-- Qompass AI Godot Native Tooling
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
-- Native Godot 4 tooling: editor/project-manager launch, running the
-- project or the current scene, headless script checks, and
-- release/debug export -- all without an external plugin.
local factory = require('utils.games.shared.godot_engine')

return factory.new({
  name = 'Godot',
  command_prefix = 'Godot',
  leader = '<leader>gg',
  binaries = { 'godot4', 'godot', 'Godot', 'Godot_v4' },
  env_names = { 'NVIM_GODOT_BIN', 'GODOT_BIN', 'GODOT4_BIN' },
  root_markers = { 'project.godot' },
  output_filetype = 'godot-output',
})
