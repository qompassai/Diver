-- #################################################################
-- /qompassai/Diver/lua/games/tic80/config.lua
-- Qompass AI TIC-80 Config
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
--- Options and verified TIC-80 CLI/console surface.
---
--- Every format list below comes from the TIC-80 wiki (verified 2026-09-28):
---   https://github.com/nesbox/TIC-80/wiki/export
---   https://github.com/nesbox/TIC-80/wiki/import
---   https://github.com/nesbox/TIC-80/wiki/command-line-arguments
---   https://github.com/nesbox/TIC-80/wiki/Hotkeys
---
--- Deliberately NOT wired (verified gaps, see actions.lua header):
--- * `import` has no sfx/music target: music is composed in the tracker.
--- * No CLI screenshot/GIF flags: F8/F9 are in-game hotkeys only.
--- * `export ... alone=1` (editor-stripped builds) is PRO-only.
---@module 'games.tic80.config'

---@class games.tic80.Options
---@field bin string? Binary name or absolute path of the tic80 executable.
---@field dirs string[]? Project directories watched for auto-restart on save.
---@field extra_args string[]? Extra CLI args placed before the cart path.
---@field auto_restart boolean? Restart the cart when a watched file is saved.

---@class games.tic80.ResolvedOptions
---@field bin string
---@field dirs string[]
---@field extra_args string[]
---@field auto_restart boolean

local M = {}

M.binaries = { 'tic80' }

M.env_names = {
    'NVIM_TIC80_BIN',
    'TIC80_BIN',
}

M.group_order = {
    'Run',
    'Cart',
    'Export',
    'Import',
    'Editors',
    'Music',
}

---Native/HTML build targets accepted by `export <fmt> <outfile>`.
---Source: wiki/export. `alone=1` is PRO-only and is never passed.
---@type string[]
M.build_formats = {
    'html',
    'binary',
    'win',
    'winxp',
    'linux',
    'rpi',
    'mac',
}

---@class games.tic80.MediaTarget
---@field kind string Console `export` target name.
---@field extension string File extension (with dot) of the produced file.
---@field needs_id boolean True when the target needs an `id=` option.

---Media targets accepted by `export <kind> <outfile> [id=N]`.
---Source: wiki/export. `sfx`/`music` export to WAV; `id` picks the sfx id
---or music track.
---@type games.tic80.MediaTarget[]
M.media_targets = {
    { kind = 'sprites', extension = '.png', needs_id = false },
    { kind = 'tiles', extension = '.png', needs_id = false },
    { kind = 'mapimg', extension = '.png', needs_id = false },
    { kind = 'map', extension = '.map', needs_id = false },
    { kind = 'screen', extension = '.png', needs_id = false },
    { kind = 'sfx', extension = '.wav', needs_id = true },
    { kind = 'music', extension = '.wav', needs_id = true },
    { kind = 'help', extension = '.md', needs_id = false },
}

---Targets accepted by `import <kind> <file>`.
---Source: wiki/import. PNG is the verified image format for tiles/sprites;
---imported colors are quantized to the nearest palette color. There is no
---sfx/music import target: music only moves cart-to-cart via `load`.
---@type string[]
M.import_kinds = {
    'sprites',
    'tiles',
    'map',
    'code',
    'screen',
}

M.output_filetype = 'tic80-output'

---@type games.tic80.ResolvedOptions
M.current = {
    bin = 'tic80',
    dirs = {},
    extra_args = { '--skip' },
    auto_restart = true,
}

---@param opts games.tic80.Options?
---@return games.tic80.ResolvedOptions
function M.resolve(opts)
    opts = opts or {}

    ---@type string[]
    local dirs = {}
    for _, dir in ipairs(opts.dirs or { '~/tic80' }) do
        dirs[#dirs + 1] = vim.fs.normalize(vim.fn.expand(dir))
    end

    ---@type string[]
    local extra_args = {}
    for _, arg in ipairs(opts.extra_args or { '--skip' }) do
        extra_args[#extra_args + 1] = arg
    end

    local auto_restart = true
    if opts.auto_restart ~= nil then
        auto_restart = opts.auto_restart
    end

    M.current = {
        bin = opts.bin or 'tic80',
        dirs = dirs,
        extra_args = extra_args,
        auto_restart = auto_restart,
    }
    return M.current
end

return M
