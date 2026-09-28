-- #################################################################
-- /qompassai/Diver/lua/games/voidsprite/config.lua
-- Qompass AI Voidsprite Config
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
--- Options for voidsprite, Matt's pixel-art editor (AUR voidsprite-git,
--- counter185/voidsprite: free C++/SDL3 pixel-art editor).
---
--- Verified CLI surface (2026-09-28): the upstream .desktop file ships
--- `Exec=voidsprite %U`, i.e. the binary opens files passed as arguments.
--- No headless/batch export CLI is documented upstream, so this module
--- wires GUI launch only; PNG export happens inside the editor and the
--- TIC-80 import bridge lives in `games.tic80.actions`.
---@module 'games.voidsprite.config'

---@class games.voidsprite.Options
---@field bin string? Binary name or absolute path of the voidsprite executable.

local M = {}

M.binaries = { 'voidsprite' }

M.env_names = {
    'NVIM_VOIDSPRITE_BIN',
    'VOIDSPRITE_BIN',
}

M.group_order = {
    'Editor',
    'TIC-80',
}

---Native session formats (.voidsnv3 documented upstream) plus the PNG
---interchange format used for the TIC-80 sprite-sheet pipeline.
---@type string[]
M.sprite_extensions = {
    '.voidsn',
    '.voidsnv3',
    '.png',
}

M.output_filetype = 'voidsprite-output'

---@param opts games.voidsprite.Options?
---@return string bin Resolved binary name or path (unvalidated).
function M.resolve(opts)
    opts = opts or {}
    return opts.bin or 'voidsprite'
end

return M
