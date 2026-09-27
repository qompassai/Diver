-- #################################################################
-- /qompassai/Diver/lua/games/love2d/adapters/unity.lua
-- Qompass AI LÖVE2D Engine Adapter: Unity
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
-- Asset interchange ONLY between Unity and LÖVE 11.5. There is no
-- LÖVE runtime interop with the Unity engine: Unity scenes, C#
-- scripts, and prefabs cannot run inside LÖVE. The only supported
-- flow is exporting flat assets (PNG sprite strips, wav/ogg audio)
-- from the Unity editor and consuming them in LÖVE.
--
-- Two explicit limits, stated because they are easy to get wrong:
--   1. Headless Unity editor scripting (the -batchmode -executeMethod
--      paths in games/unity/actions.lua) cannot be validated in this
--      sandbox -- no Unity editor is present here, so the adapter
--      asserts nothing about editor-side behavior.
--   2. No Unity editor C# APIs are invented or asserted anywhere in
--      this adapter; the interchange surface is files, not APIs.
local M = {}

-- Largest interchange-manifest asset list the validator will walk.
local MANIFEST_ASSETS_MAX = 256

-- File kinds the interchange manifest accepts. LÖVE-native raster and
-- audio only: Unity's .fbx/.prefab/.unity formats are NOT accepted --
-- meshes cross over only via Blender as the conversion step.
local MANIFEST_KINDS = { png = true, json = true, ogg = true, wav = true }

M.engine_key = 'unity'
M.label = 'Unity'
-- The LÖVE side is pinned to the managed 11.5. No Unity-version
-- requirement is stated here: there is no LÖVE runtime interop with
-- the Unity engine, so the Unity runtime version is not this
-- adapter's business.
M.love_version_requirement = '11.5'

-- anim8: sprite strips exported from Unity (PNG), played as
-- frame-grid animations. Audio needs no catalog library: love.audio
-- plays wav/ogg natively. FBX is deliberately absent: LÖVE has no
-- FBX loader, so meshes cross over via Blender baking instead.
M.libraries = { 'anim8' }

M.asset_interchange = {
    capabilities = {
        'sprite strips exported from Unity (PNG) as anim8 frame-grid animations',
        'audio (wav/ogg) through native love.audio -- no library needed',
        'FBX interchange only via Blender as the conversion step (Blender bakes; LÖVE has no FBX loader)',
    },
    limits = {
        'asset interchange ONLY: there is no LÖVE runtime interop with the Unity engine',
        'headless Unity editor scripting (games/unity/actions.lua -batchmode -executeMethod) '
            .. 'cannot be validated in this sandbox -- no Unity editor is present; '
            .. 'asset exports require the editor',
        'no Unity editor C# APIs are asserted here; the interchange surface is files, not APIs',
    },
    runtime_interop = false,
}

---Recommended conf.lua values for LÖVE projects consuming
---Unity-exported assets. Convention only; nothing reads or enforces
---these.
M.run_config = {
    identity = 'diver-unity-love',
    window = { width = 1280, height = 720, resizable = true, vsync = 1 },
}

---Recommended packaging conventions for Unity-sourced assets.
M.package_config = {
    asset_dirs = { 'assets', 'sprites' },
    include_exts = { '.png', '.json', '.ogg', '.wav' },
}

---@class UnityInterchangeAsset
---@field path string relative path of the asset file
---@field kind string interchange file kind ('png', 'json', 'ogg' or 'wav')

---@class UnityInterchangeManifest
---@field engine string engine_key this manifest was built for
---@field assets UnityInterchangeAsset[] asset files handed to LÖVE

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

---Unity editor detection is project-bound (no canonical PATH binary:
---the editor launches through Unity Hub against a project), so this
---environment cannot resolve one. Fails closed by design; a
---project-aware probe belongs in games/unity/util, not in this
---adapter. Never returns a guessed path.
---@return nil path
---@return string err
function M.detect_tooling()
    return nil, 'unity editor not detectable without a Unity project on disk'
end

return M
