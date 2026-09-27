-- #################################################################
-- /qompassai/Diver/lua/games/love2d/adapters/redot.lua
-- Qompass AI LÖVE2D Engine Adapter: Redot
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
-- Asset interchange between Redot and LÖVE 11.5. Redot is a Godot 4
-- fork, so the interchange formats are identical to the godot adapter
-- (sprite sheets, audio, tilemap shape data). Same honesty rule
-- applies: asset interchange only, no runtime bridge -- Redot scenes
-- and scripts cannot run inside LÖVE, so runtime_interop=false even
-- though the contract's thin-integration hint list does not name
-- 'redot' explicitly.
local M = {}

-- Largest interchange-manifest asset list the validator will walk.
local MANIFEST_ASSETS_MAX = 256

-- File kinds the interchange manifest accepts. LÖVE-native raster and
-- audio only: nothing here implies a Redot scene or script format.
local MANIFEST_KINDS = { png = true, json = true, ogg = true, wav = true }

M.engine_key = 'redot'
M.label = 'Redot'
M.love_version_requirement = '11.5'

-- anim8: sprite strips exported from Redot as PNG, played as
-- frame-grid animations.
-- bump: AABB collision shapes converted from Redot TileMap/physics
-- data into bump.lua worlds. Audio needs no catalog library:
-- love.audio plays wav/ogg natively.
M.libraries = { 'anim8', 'bump' }

M.asset_interchange = {
    capabilities = {
        'sprite sheets exported from Redot (PNG) as anim8 frame-grid animations',
        'audio (wav/ogg) through native love.audio -- no library needed',
        'AABB collision shapes converted from Redot TileMap data into bump.lua worlds',
    },
    limits = {
        'asset interchange only: Redot scenes, scripts and the Redot runtime '
            .. 'cannot run in LÖVE; there is no runtime bridge',
        'tilemap conversion is shape-data only; no scene-tree semantics cross over',
        'no LÖVE runtime interop with the Redot engine',
    },
    runtime_interop = false,
}

---Recommended conf.lua values for LÖVE projects consuming Redot
---assets. Convention only; nothing reads or enforces these.
M.run_config = {
    identity = 'diver-redot-love',
    window = { width = 1280, height = 720, resizable = true, vsync = 1 },
}

---Recommended packaging conventions for Redot-sourced assets.
M.package_config = {
    asset_dirs = { 'assets', 'sprites', 'audio' },
    include_exts = { '.png', '.json', '.ogg', '.wav' },
}

---@class RedotInterchangeAsset
---@field path string relative path of the asset file
---@field kind string interchange file kind ('png', 'json', 'ogg' or 'wav')

---@class RedotInterchangeManifest
---@field engine string engine_key this manifest was built for
---@field assets RedotInterchangeAsset[] asset files handed to LÖVE

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

---Locate a Redot binary (redot4 preferred, redot accepted). Returns
---nil when absent: the adapter fails closed rather than assuming an
---editor is installed.
---@return string? path
---@return string? err
function M.detect_tooling()
    if vim.fn.executable('redot4') == 1 then
        return 'redot4', nil
    end
    if vim.fn.executable('redot') == 1 then
        return 'redot', nil
    end
    return nil, 'redot binary not found on PATH'
end

return M
