-- #################################################################
-- /qompassai/Diver/lua/games/love2d/init.lua
-- Qompass AI LÖVE2D Platform Core
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
-- Centralized LÖVE2D platform core: pinned 11.5 runtime management,
-- deterministic .love packaging, per-OS release fusion, a curated library
-- catalog, the dev loop (run / hot-reload / debug console / profiler), an
-- engine adapter contract, and health checks.
--
-- Engine wiring into games/init.lua happens in a later integration pass;
-- see the track report for the snippet.
local M = {}
M.actions = require('games.love2d.actions')
M.adapters = require('games.love2d.adapters')
M.commands = require('games.love2d.commands')

M.config = require('games.love2d.config')
M.dev = require('games.love2d.dev')
M.health = require('games.love2d.health')
M.libs = require('games.love2d.libs')
M.package = require('games.love2d.package')
M.release = require('games.love2d.release')
M.versions = require('games.love2d.versions')

function M.setup()
    M.commands.setup()
end
M.run_action_by_id = M.actions.run_action_by_id

M.show_menu = M.actions.show_menu

return M
