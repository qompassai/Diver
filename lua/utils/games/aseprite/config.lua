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
M.group_order = { 'Editor', 'Export', 'Palette', 'Scripting' }

-- Aseprite's own "Options > Manage Palettes" folder, one per OS --
-- the equivalent of knowing where a daemon reads its drop-in config
-- fragments from (think `/etc/NetworkManager/conf.d/`): a `.gpl`
-- file copied here shows up in Aseprite's own Palette menu next
-- time it starts, without editing any Aseprite settings by hand.
M.user_palette_dir_by_os = {
  windows = (vim.fn.expand('$APPDATA') or '') .. '/Aseprite/palettes',
  mac = (vim.fn.expand('$HOME') or '') .. '/Library/Application Support/Aseprite/palettes',
  linux = (vim.fn.expand('$HOME') or '') .. '/.config/aseprite/palettes',
}

-- Valid `--sheet-type` values Aseprite's CLI accepts for a sprite
-- sheet/tileset export -- see `aseprite --help`. Kept as an explicit
-- fixed list (Tiger Style) rather than accepting arbitrary user text,
-- so a typo fails at the picker instead of as a cryptic CLI error.
M.sheet_types = { 'packed', 'rows', 'columns', 'horizontal', 'vertical' }

return M
