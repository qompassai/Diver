-- #################################################################
-- /qompassai/Diver/lua/utils/games/redot/init.lua
-- Qompass AI Redot Native Tooling
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
-- Native Redot 4 tooling. Redot is a community fork of Godot 4 that
-- keeps project.godot/.tscn/.gd compatibility, so this module reuses
-- utils.games.shared.godot_engine with Redot-specific binaries, env
-- vars, and keymaps -- it never shares cache/output state with Godot.
local factory = require('utils.games.shared.godot_engine')

return factory.new({
  name = 'Redot',
  command_prefix = 'Redot',
  leader = '<leader>gr',
  binaries = { 'redot4', 'redot', 'Redot', 'Redot_v4' },
  env_names = { 'NVIM_REDOT_BIN', 'REDOT_BIN', 'REDOT4_BIN' },
  root_markers = { 'project.godot' },
  output_filetype = 'redot-output',
})
