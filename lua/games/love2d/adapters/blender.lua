-- #################################################################
-- /qompassai/Diver/lua/games/love2d/adapters/blender.lua
-- Qompass AI LÖVE2D Engine Adapter: Blender
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
-- Asset interchange between Blender and LÖVE 11.5. The LÖVE-bound path
-- is sprite baking: games/blender/sprites.lua renders scene animation
-- frames (or a camera turntable) with a fixed orthographic preset and
-- packs them into a single-row PNG strip plus a JSON frame manifest,
-- using a hand-rolled PNG writer -- zero host image tooling beyond
-- Blender itself. glTF/GLB is NOT a LÖVE runtime format, so the
-- glb/fbx exporters in games/blender/export.lua are interchange-only:
-- Blender meshes reach LÖVE as baked sprites.
--
-- Assumption about the in-flight Blender track (Track C, 2026-09-27):
-- this adapter assumes games.blender.sprites exposes
-- validate_manifest/1 for the diver-blender-sprites manifest format
-- (verified present on 2026-09-27: sprites.lua, render.lua,
-- export.lua, batch.lua, health.lua, versions.lua all exist with the
-- bake/render/export entry points documented above). The require is
-- pcall-guarded, so if Track C reshapes or renames that surface the
-- adapter fails closed here instead of breaking at load time.
local M = {}

-- Track C surface guard: pcall so an in-flight reshape fails closed.
local sprites_ok, sprites = pcall(require, 'games.blender.sprites')

M.engine_key = 'blender'
M.label = 'Blender'
M.love_version_requirement = '11.5'

-- anim8: plays the baked single-row strips (pack_strip output) as
-- frame-grid animations in LÖVE.
-- g3d: loads Blender-exported .obj models via g3d's objloader only;
-- the adapter's bake-first limits explain why glTF/GLB is excluded.
M.libraries = { 'anim8', 'g3d' }

M.asset_interchange = {
    capabilities = {
        'sprite-sheet baking from .blend scenes via games/blender/sprites.lua '
            .. '(hand-rolled PNG writer; no host image tooling beyond Blender)',
        'still and turntable-orbit renders for cutscene/reference art via games/blender/render.lua',
        'baked-strip manifest validated by games/blender/sprites.validate_manifest (format diver-blender-sprites)',
    },
    limits = {
        'glTF/GLB is NOT a LÖVE runtime format: the glb/fbx exporters in games/blender/export.lua '
            .. 'are interchange-only; Blender meshes reach LÖVE as baked sprite strips',
        'g3d loads .obj only; no LÖVE loader exists for .glb/.fbx',
        'no runtime interop: Blender never runs inside LÖVE; interchange is files only',
        'fails closed when the Blender binary is absent',
    },
    runtime_interop = false,
}

---Recommended conf.lua values for LÖVE projects consuming baked
---Blender assets. Convention only; nothing reads or enforces these.
M.run_config = {
    identity = 'diver-blender-love',
    window = { width = 1280, height = 720, resizable = true, vsync = 1 },
}

---Recommended packaging conventions for Blender-baked assets.
M.package_config = {
    asset_dirs = { 'assets', 'renders', 'sprites' },
    include_exts = { '.png', '.json', '.ogg', '.wav' },
}

---Validate a baked-sprite manifest against the real Blender sprite
---pipeline schema (format diver-blender-sprites). Fails closed when
---the pipeline module is unavailable -- a malformed or unvalidated
---manifest never reaches the packer.
---@param manifest any decoded manifest table
---@return boolean ok
---@return string? err
function M.validate_interchange_manifest(manifest)
    if not sprites_ok or type(sprites) ~= 'table' or type(sprites.validate_manifest) ~= 'function' then
        return false, 'blender sprite pipeline unavailable (games.blender.sprites not loaded)'
    end
    return sprites.validate_manifest(manifest)
end

---Locate the Blender binary. Returns nil when absent: the adapter
---fails closed rather than assuming Blender is installed.
---@return string? path
---@return string? err
function M.detect_tooling()
    if vim.fn.executable('blender') == 1 then
        return 'blender', nil
    end
    return nil, 'blender binary not found on PATH'
end

return M
