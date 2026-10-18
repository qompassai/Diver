-- /qompassai/Diver/lua/games/blender/config.lua
-- Qompass AI Blender Config
---@module 'games.blender.config'
-- Blender engine configuration: binary discovery, the pinned
-- release this module was validated against, and every bound the
-- engine enforces (resolution, samples, frames, batch sizes,
-- timeouts). This module spawns nothing; it only describes limits.

---@class BlenderRenderCaps
---@field height_max integer Hard cap on render height, in pixels
---@field samples_default integer Default render samples
---@field samples_max integer Hard cap on render samples
---@field timeout_ms_default integer Default per-render timeout, in milliseconds
---@field timeout_ms_max integer Hard cap on any single render timeout, in milliseconds
---@field turntable_frames_default integer Default turntable frame count
---@field turntable_frames_max integer Hard cap on turntable frame count
---@field width_max integer Hard cap on render width, in pixels

---@class BlenderBatchCaps
---@field blend_max integer Hard cap on .blend files processed in one batch run
---@field timeout_ms_default integer Default per-file timeout, in milliseconds
---@field timeout_ms_max integer Hard cap on per-file timeout, in milliseconds

---@class BlenderConfig
---@field batch BlenderBatchCaps
---@field binaries string[] Binary names probed on PATH
---@field env_names string[] Environment variables holding an explicit binary path
---@field group_order string[] Action menu group ordering
---@field manifest_version integer Sprite manifest schema version
---@field min_version string Oldest release the CLI wrappers support
---@field output_filetype string Output window filetype
---@field pinned_version string Release this module was validated against
---@field render BlenderRenderCaps
---@field tools_dir string Managed install root (~/workspace/tools/blender)

---@type BlenderConfig
local M = {

    batch = {
        blend_max = 32,
        timeout_ms_default = 300000,
        timeout_ms_max = 1800000,
    },
    binaries = {
        'blender',
    },

    env_names = {
        'BLENDER_BIN',
        'NVIM_BLENDER_BIN',
    },

    group_order = {
        'Render',
        'Export',
        'Sprites',
        'Batch',
        'Scripting',
    },

    manifest_version = 1,
    min_version = '4.0.0',

    output_filetype = 'blender-output',

    -- Pinned to the release validated by track C (2026-09-27).
    pinned_version = '5.2.2',

    render = {
        height_max = 4096,
        samples_default = 32,
        samples_max = 256,
        timeout_ms_default = 300000,
        timeout_ms_max = 1800000,
        turntable_frames_default = 8,
        turntable_frames_max = 64,
        width_max = 4096,
    },

    -- Managed install root (~/workspace/tools/blender).
    tools_dir = vim.fn.expand('~/workspace/tools/blender'),
}

return M
