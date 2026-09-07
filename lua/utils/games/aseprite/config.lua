-- #################################################################
-- /qompassai/Diver/lua/utils/games/aseprite/config.lua
-- Qompass AI Aseprite Config
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

M.binaries = { 'aseprite', 'Aseprite' }
M.env_names = { 'NVIM_ASEPRITE_BIN', 'ASEPRITE_BIN' }
M.sprite_extensions = { '.aseprite', '.ase' }
M.output_filetype = 'aseprite-output'
M.group_order = { 'Editor', 'Export', 'Scripting' }

return M
