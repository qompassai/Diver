-- #################################################################
-- /qompassai/Diver/lua/games/godot/character.lua
-- Qompass AI Godot Character Builder
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
-- Godot character interchange artifacts. Thin wrapper over the
-- shared factory (games.shared.godot_character): this file supplies
-- the Godot descriptor and the Godot-named LuaCATS classes; all
-- behavior lives in the factory. Pure at require time.

---@class GodotCharacterOpts
---@field bin? string explicit engine binary override
---@field fps? number bake fps override
---@field name? string character name override (sanitized)

---@class GodotInterchangeFile
---@field path string relative path
---@field content string file text

return require('games.shared.godot_character').build({
    binaries = { 'godot4', 'godot', 'Godot', 'Godot_v4' },
    display = 'Godot',
    env_names = { 'NVIM_GODOT_BIN', 'GODOT_BIN', 'GODOT4_BIN' },
    manifest_format = 'diver-character-godot',
    module_path = 'games/godot/character.lua',
})
