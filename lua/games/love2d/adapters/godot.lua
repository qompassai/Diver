-- #################################################################
-- /qompassai/Diver/lua/games/love2d/adapters/godot.lua
-- Qompass AI LÖVE2D Engine Adapter: Godot 4
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
-- Asset interchange between Godot 4 and LÖVE 11.5: sprite sheets,
-- audio, and tilemap shape data, exported from a Godot project and
-- consumed by LÖVE libraries. There is no runtime bridge -- GDScript,
-- .tscn/.godot scenes, and the Godot runtime cannot run inside LÖVE,
-- so this adapter declares runtime_interop=false (the contract also
-- enforces it for the 'godot' thin-integration hint).
local M = {}

-- Largest interchange-manifest asset list the validator will walk.
local MANIFEST_ASSETS_MAX = 256

-- File kinds the interchange manifest accepts. LÖVE-native raster and
-- audio only: nothing here implies a Godot scene or script format.
local MANIFEST_KINDS = { png = true, json = true, ogg = true, wav = true }

M.engine_key = 'godot'
M.label = 'Godot 4'
M.love_version_requirement = '11.5'

-- anim8: sprite strips exported from Godot as PNG, played as
-- frame-grid animations.
-- bump: AABB collision shapes converted from Godot TileMap/physics
-- data into bump.lua worlds. Audio needs no catalog library:
-- love.audio plays wav/ogg natively.
M.libraries = { 'anim8', 'bump' }

M.asset_interchange = {
    capabilities = {
        'sprite sheets exported from Godot (PNG) as anim8 frame-grid animations',
        'audio (wav/ogg) through native love.audio -- no library needed',
        'AABB collision shapes converted from Godot TileMap data into bump.lua worlds',
    },
    limits = {
        'asset interchange only: GDScript, .tscn/.godot scenes and the Godot runtime '
            .. 'cannot run in LÖVE; there is no runtime bridge',
        'tilemap conversion is shape-data only; no scene-tree semantics cross over',
        'no LÖVE runtime interop with the Godot engine',
    },
    runtime_interop = false,
}

---Recommended conf.lua values for LÖVE projects consuming Godot
---assets. Convention only; nothing reads or enforces these.
M.run_config = {
    identity = 'diver-godot-love',
    window = { width = 1280, height = 720, resizable = true, vsync = 1 },
}

---Recommended packaging conventions for Godot-sourced assets.
M.package_config = {
    asset_dirs = { 'assets', 'sprites', 'audio' },
    include_exts = { '.png', '.json', '.ogg', '.wav' },
}

---@class GodotInterchangeAsset
---@field path string relative path of the asset file
---@field kind string interchange file kind ('png', 'json', 'ogg' or 'wav')

---@class GodotInterchangeManifest
---@field engine string engine_key this manifest was built for
---@field assets GodotInterchangeAsset[] asset files handed to LÖVE

-- Validate one asset entry: a table with a safe relative path and a
-- LÖVE-native kind. Pure; no filesystem access. Returns an error
-- string, or nil when the entry is sound.
---@param asset any
---@return string? err
local function validate_asset(asset)
    if type(asset) ~= 'table' then
        return 'manifest asset must be a table'
    end
    if type(asset.path) ~= 'string' or asset.path == '' then
        return 'manifest asset path must be a non-empty string'
    end
    if asset.path:find('..', 1, true) ~= nil then
        return 'manifest asset path must not contain ..'
    end
    if MANIFEST_KINDS[asset.kind] ~= true then
        return 'manifest asset kind must be one of png, json, ogg, wav'
    end
    return nil
end

---Validate an interchange manifest for this adapter. Pure: rejects
---malformed manifests without touching the filesystem or the engine.
---@param manifest any decoded manifest table
---@return boolean ok
---@return string? err
function M.validate_interchange_manifest(manifest)
    if type(manifest) ~= 'table' then
        return false, 'manifest must be a table'
    end
    if manifest.engine ~= M.engine_key then
        return false, 'manifest engine must be ' .. M.engine_key
    end
    if type(manifest.assets) ~= 'table' or #manifest.assets == 0 then
        return false, 'manifest assets must be a non-empty list'
    end
    if #manifest.assets > MANIFEST_ASSETS_MAX then
        return false, 'manifest lists too many assets'
    end
    for index, asset in ipairs(manifest.assets) do
        local err = validate_asset(asset)
        if err ~= nil then
            return false, ('manifest asset %d: %s'):format(index, err)
        end
    end
    return true, nil
end

---Locate a Godot 4 binary (godot4 preferred, godot accepted). Returns
---nil when absent: the adapter fails closed rather than assuming an
---editor is installed.
---@return string? path
---@return string? err
function M.detect_tooling()
    if vim.fn.executable('godot4') == 1 then
        return 'godot4', nil
    end
    if vim.fn.executable('godot') == 1 then
        return 'godot', nil
    end
    return nil, 'godot binary not found on PATH'
end

return M
