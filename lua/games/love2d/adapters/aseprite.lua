-- #################################################################
-- /qompassai/Diver/lua/games/love2d/adapters/aseprite.lua
-- Qompass AI LÖVE2D Engine Adapter: Aseprite
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
-- Asset interchange between Aseprite and LÖVE 11.5. This is the
-- strongest of the six adapters: Aseprite exports raster sprite sheets
-- plus an optional JSON sidecar (frame rects, tags), and both halves
-- have a real LÖVE consumer (peachy, anim8). Interchange is files
-- only -- Aseprite never runs inside LÖVE.
--
-- Sprite flow assumed (see games/aseprite/import.lua): AI art goes
-- through the import pipeline (background removal, nearest-neighbor
-- downscale to a frame size, palette quantization), the clean PNG is
-- finished by hand in Aseprite, and the exported sheet + JSON land in
-- the LÖVE project for peachy or anim8 to play.
local M = {}

-- Largest interchange-manifest asset list the validator will walk.
local MANIFEST_ASSETS_MAX = 256

-- File kinds the interchange manifest accepts. LÖVE-native raster and
-- audio only: nothing here implies a foreign scene or model format.
local MANIFEST_KINDS = { png = true, json = true, ogg = true, wav = true }

M.engine_key = 'aseprite'
M.label = 'Aseprite'
M.love_version_requirement = '11.5'

-- peachy: consumes Aseprite's sheet + JSON export with tags intact as
-- ready-to-play LÖVE animations (catalog category 'aseprite').
-- anim8: covers sheets exported WITHOUT the JSON sidecar, where the
-- frames form a plain grid and no tag metadata exists to consume.
M.libraries = { 'peachy', 'anim8' }

M.asset_interchange = {
    capabilities = {
        'sprite sheets from the games/aseprite/import.lua pipeline '
            .. '(bg removal, nearest-neighbor downscale, palette quantization)',
        'tagged animations via Aseprite JSON export, consumed by peachy with tags intact',
        'LuaJIT-compatible PNG dimension probing for frame-size math (no string.unpack)',
    },
    limits = {
        'no runtime interop: Aseprite never runs inside LÖVE; interchange is files only',
        'the Aseprite CLI path leaves palette quantization manual (Sprite > Color Mode > Indexed)',
        'peachy reads the exported JSON + sheet, not .ase project files directly',
    },
    runtime_interop = false,
}

---Recommended conf.lua values for LÖVE projects consuming Aseprite
---assets. Convention only; nothing reads or enforces these.
M.run_config = {
    identity = 'diver-aseprite-love',
    window = { width = 1280, height = 720, resizable = true, vsync = 1 },
}

---Recommended packaging conventions for Aseprite-sourced assets.
M.package_config = {
    asset_dirs = { 'assets', 'sprites' },
    include_exts = { '.png', '.json', '.ogg', '.wav' },
}

---@class AsepriteInterchangeAsset
---@field path string relative path of the asset file
---@field kind string interchange file kind ('png', 'json', 'ogg' or 'wav')

---@class AsepriteInterchangeManifest
---@field engine string engine_key this manifest was built for
---@field assets AsepriteInterchangeAsset[] asset files handed to LÖVE

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

---Locate the Aseprite binary. Returns nil when absent: the adapter
---fails closed rather than assuming an editor is installed.
---@return string? path
---@return string? err
function M.detect_tooling()
    if vim.fn.executable('aseprite') == 1 then
        return 'aseprite', nil
    end
    return nil, 'aseprite binary not found on PATH'
end

return M
