-- #################################################################
-- /qompassai/Diver/lua/games/voidsprite/init.lua
-- Qompass AI Voidsprite Native Tooling
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
--- Native voidsprite tooling: launch the editor against the current sprite
--- file and bridge PNG sprite sheets into TIC-80 carts -- no plugin.
---
--- Matt's pixel-art editor is voidsprite (AUR voidsprite-git); it is
--- Aseprite-compatible in spirit but this module does not reuse
--- `games.aseprite`: the aseprite module is built around Aseprite's
--- `-b`/`--script` batch CLI and preferences schema, none of which is
--- documented for voidsprite. The only verified voidsprite CLI surface is
--- `voidsprite <file>`, so this module stays small on purpose.
---@module 'games.voidsprite'

local config = require('games.voidsprite.config')
local util = require('games.voidsprite.util')
local actions = require('games.voidsprite.actions')
local commands = require('games.voidsprite.commands')

local M = {}

M.config = config
M.util = util
M.actions = actions
M.commands = commands

---@param opts games.voidsprite.Options?
function M.setup(opts)
    util.configure(opts)
    commands.setup()
end

M.show_menu = actions.show_menu
M.run_action_by_id = actions.run_action_by_id

return M
