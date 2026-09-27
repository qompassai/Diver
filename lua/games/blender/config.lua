-- #################################################################
-- /qompassai/Diver/lua/games/blender/config.lua
-- Qompass AI Blender Config
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
-- Blender engine configuration: binary discovery, the pinned
-- release this module was validated against, and every bound the
-- engine enforces (resolution, samples, frames, batch sizes,
-- timeouts). This module spawns nothing; it only describes limits.

---@class BlenderRenderCaps
---@field width_max integer Hard cap on render width, in pixels
---@field height_max integer Hard cap on render height, in pixels
---@field samples_max integer Hard cap on render samples
---@field samples_default integer Default render samples
---@field timeout_ms_default integer Default per-render timeout, in milliseconds
---@field timeout_ms_max integer Hard cap on any single render timeout, in milliseconds
---@field turntable_frames_default integer Default turntable frame count
---@field turntable_frames_max integer Hard cap on turntable frame count

---@class BlenderBatchCaps
---@field blend_max integer Hard cap on .blend files processed in one batch run
---@field timeout_ms_default integer Default per-file timeout, in milliseconds
---@field timeout_ms_max integer Hard cap on per-file timeout, in milliseconds

---@class BlenderConfig
---@field binaries string[] Binary names probed on PATH
---@field env_names string[] Environment variables holding an explicit binary path
---@field tools_dir string Managed install root (~/workspace/tools/blender)
---@field pinned_version string Release this module was validated against
---@field min_version string Oldest release the CLI wrappers support
---@field group_order string[] Action menu group ordering
---@field output_filetype string Output window filetype
---@field render BlenderRenderCaps
---@field batch BlenderBatchCaps
---@field manifest_version integer Sprite manifest schema version

---@type BlenderConfig
local M = {
    binaries = {
        'blender',
    },

    env_names = {
        'BLENDER_BIN',
        'NVIM_BLENDER_BIN',
    },

    -- Managed install root (~/workspace/tools/blender).
    tools_dir = vim.fn.expand('~/workspace/tools/blender'),

    -- Pinned to the release validated by track C (2026-09-27).
    pinned_version = '5.2.2',
    min_version = '4.0.0',

    group_order = {
        'Render',
        'Export',
        'Sprites',
        'Batch',
        'Scripting',
    },

    output_filetype = 'blender-output',

    render = {
        width_max = 4096,
        height_max = 4096,
        samples_max = 256,
        samples_default = 32,
        timeout_ms_default = 300000,
        timeout_ms_max = 1800000,
        turntable_frames_default = 8,
        turntable_frames_max = 64,
    },

    batch = {
        blend_max = 32,
        timeout_ms_default = 300000,
        timeout_ms_max = 1800000,
    },

    manifest_version = 1,
}

return M
