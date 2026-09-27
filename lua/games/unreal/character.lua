-- #################################################################
-- /qompassai/Diver/lua/games/unreal/character.lua
-- Qompass AI Unreal Character Builder
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
-- Unreal import-pipeline hooks ONLY from a validated shared-character
-- definition: a JSON frame manifest + a Python Editor Utility stub as
-- text artifacts. 3D models travel via the Blender interchange
-- pipeline (games.blender.character build_blend + export FBX/glTF).
--
-- Explicit limits: no runtime bridge exists here. Headless Unreal
-- editor scripting cannot be validated in this sandbox; the Python
-- stub is a starting point, not a working integration. Pure at
-- require time; only export_model() needs Neovim + a blender binary,
-- and it fails closed otherwise.
local kit = require('games.shared.character')

local M = {}

M.FRAMES_MAX = 4096
M.JSON_DEPTH_MAX = 16
M.NAME_LEN_MAX = 48

---@class UnrealCharacterOpts
---@field name? string character name override (sanitized)
---@field fps? number bake fps override

---@class UnrealInterchangeFile
---@field path string relative path
---@field content string file text

---@param v any
---@param depth integer
---@return string|nil chunk
local function encode_json(v, depth)
    if depth > M.JSON_DEPTH_MAX then
        return nil
    end
    local tv = type(v)
    if tv == 'nil' then
        return 'null'
    end
    if tv == 'boolean' then
        return v and 'true' or 'false'
    end
    if tv == 'number' then
        if v ~= v or math.abs(v) == math.huge then
            return nil
        end
        if v == math.floor(v) and math.abs(v) < 1e15 then
            return string.format('%d', v)
        end
        return tostring(v)
    end
    if tv == 'string' then
        if v:find('%z') ~= nil then
            return nil
        end
        return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    end
    if tv ~= 'table' then
        return nil
    end
    local n = #v
    local is_seq = true
    for k in pairs(v) do
        if type(k) ~= 'number' or k < 1 or k > n or k ~= math.floor(k) then
            is_seq = false
            break
        end
    end
    local parts = {}
    if is_seq then
        for i = 1, n do
            local item = encode_json(v[i], depth + 1)
            if item == nil then
                return nil
            end
            parts[#parts + 1] = item
        end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = {}
    for k in pairs(v) do
        if type(k) ~= 'string' then
            return nil
        end
        keys[#keys + 1] = k
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local key, item = encode_json(k, depth + 1), encode_json(v[k], depth + 1)
        if key == nil or item == nil then
            return nil
        end
        parts[#parts + 1] = key .. ':' .. item
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

---@param name string
---@return string safe single path segment
local function sanitize_name(name)
    local safe = tostring(name):gsub('[%c%z]', ''):gsub('[^%w%-_]', '_'):sub(1, M.NAME_LEN_MAX)
    if safe == '' then
        return 'character'
    end
    return safe
end

---@param sprite string|nil
---@param part_name string
---@return string|nil safe
---@return string|nil err
local function check_sprite_path(sprite, part_name)
    if sprite == nil then
        return nil, nil
    end
    if sprite:sub(1, 1) == '/' or sprite:find('%.%.') ~= nil or sprite:find('%z') ~= nil then
        return nil, "unreal: unsafe sprite path for part '" .. part_name .. "'"
    end
    return sprite, nil
end

---@param ch table validated character
---@param opts? UnrealCharacterOpts
---@return table|nil manifest
---@return string|nil err
local function build_manifest(ch, opts)
    opts = opts or {}
    local parts = {}
    for _, part in ipairs(ch.parts) do
        local sprite, serr = check_sprite_path(part.sprite, part.name)
        if serr ~= nil then
            return nil, serr
        end
        parts[#parts + 1] = {
            name = part.name,
            anchor = { part.anchor.x, part.anchor.y },
            zindex = part.zindex,
            sprite = sprite,
        }
    end
    local anims = {}
    for anim_name, tl in pairs(ch.timelines) do
        local fps = opts.fps or tl.fps
        if type(fps) ~= 'number' or fps <= 0 or fps > kit.FPS_MAX then
            return nil, 'unreal: fps out of range'
        end
        local count = math.floor(tl.duration_sec * fps + 1e-9) + 1
        if count > M.FRAMES_MAX then
            return nil, 'unreal: frame count exceeds cap'
        end
        local frames = {}
        for i = 1, count do
            local t = math.min((i - 1) / fps, tl.duration_sec)
            local pose, perr = kit.sample_pose(ch, anim_name, t)
            if pose == nil then
                return nil, 'unreal: sample_pose failed: ' .. tostring(perr)
            end
            local baked = {}
            for _, part in ipairs(ch.parts) do
                local s = pose[part.name]
                baked[part.name] = {
                    pos = { s.pos.x, s.pos.y },
                    rot = s.rot_deg,
                    scale = { s.scale.x, s.scale.y },
                    visible = s.visible,
                }
            end
            frames[i] = { t = t, parts = baked }
        end
        anims[anim_name] = { fps = fps, loop = tl.loop, frames = frames }
    end
    return {
        format = 'diver-character-unreal',
        version = 1,
        character = ch.name,
        parts = parts,
        anims = anims,
    },
        nil
end

local PYTHON_TEMPLATE = [==[
# Generated by diver games/unreal/character.lua -- IMPORT STUB, a starting
# point, not a working integration. Run inside the Unreal editor via the
# Python Editor Script Plugin: it reads manifest.json next to this file,
# spawns one Paper2D sprite component per part under an Actor, and logs
# the baked timeline names. Wire the flipbook/sequencer binding yourself;
# no runtime bridge is provided by this module.
import json
import os
import unreal

MANIFEST = os.path.join(os.path.dirname(__file__), "manifest.json")

def import_character():
    with open(MANIFEST, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    character = manifest.get("character", "character")
    actor = unreal.EditorLevelLibrary.spawn_actor_from_class(
        unreal.Actor, unreal.Vector(0.0, 0.0, 0.0)
    )
    actor.set_actor_label("Diver_" + character)
    for part in manifest.get("parts", []):
        comp = unreal.PaperSpriteComponent()
        comp.set_editor_property("translucency_sort_priority", int(part["zindex"]))
        actor.add_instance_component(comp)
        unreal.log("diver: stub would attach part %s (sprite %s)" % (part["name"], part.get("sprite")))
    unreal.log("diver: import stub for %s; timelines: %s"
               % (character, sorted(manifest.get("anims", {}).keys())))

if __name__ == "__main__":
    import_character()
]==]

local README_TEMPLATE = [==[
Diver character interchange for Unreal -- @@SAFE@@
==================================================
Generated by diver games/unreal/character.lua.

Contents:
  manifest.json            Baked 2D frame data (parts, anchors, z-order,
                           per-frame pos/rot/scale/visible per timeline).
  import_@@SAFE@@.py       Python Editor Utility STUB. Starting point, not
                           a working integration: no runtime bridge here.

3D path (documented, not automated):
  Build an armature .blend with games.blender.character build_blend()
  (kind 'armature3d'), export FBX via export_interchange(), then import
  the FBX in Unreal and set up the skeleton there. Headless Unreal
  editor scripting cannot be validated in this sandbox.
]==]

---Build the Unreal interchange set: manifest.json + Python editor
---stub + README. Validates first; hostile definitions are rejected
---with nil, err before any artifact text is produced.
---@param ch table character definition
---@param opts? UnrealCharacterOpts
---@return { files: UnrealInterchangeFile[] }|nil bundle
---@return string|nil err
function M.build_interchange(ch, opts)
    opts = opts or {}
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, 'unreal: invalid character: ' .. tostring(verr[1])
    end
    if next(ch.timelines) == nil then
        return nil, 'unreal: character has no timelines to bake'
    end
    local safe = sanitize_name(opts.name or ch.name)
    local manifest, merr = build_manifest(ch, opts)
    if manifest == nil then
        return nil, merr
    end
    local encoded = encode_json(manifest, 0)
    if encoded == nil then
        return nil, 'unreal: manifest is not JSON-serializable'
    end
    local readme = README_TEMPLATE:gsub('@@SAFE@@', safe)
    return {
        files = {
            { path = 'manifest.json', content = encoded .. '\n' },
            { path = 'import_' .. safe .. '.py', content = PYTHON_TEMPLATE },
            { path = 'README_diver_character.txt', content = readme },
        },
    },
        nil
end

---Export a 3D model for Unreal via the Blender interchange pipeline
---(build_blend kind 'armature3d', then FBX/glTF export). Delegates to
---games.blender.character and fails closed when Blender or Neovim is
---unavailable -- there is no Unreal-side automation here.
---@param ch table character definition
---@param out_path string destination .fbx/.glb path
---@param kind string 'fbx' | 'glb'
---@param opts? { bin?: string, fps?: number }
---@return string|nil out_path
---@return string|nil err
function M.export_model(ch, out_path, kind, opts)
    opts = opts or {}
    if kind ~= 'fbx' and kind ~= 'glb' then
        return nil, "unreal: kind must be 'fbx' or 'glb'"
    end
    if type(out_path) ~= 'string' or out_path == '' then
        return nil, 'unreal: out_path required'
    end
    local has_mod, blender_character = pcall(require, 'games.blender.character')
    if not has_mod then
        return nil, 'unreal: games.blender.character unavailable: ' .. tostring(blender_character)
    end
    if vim == nil or vim.fn == nil then
        return nil, 'unreal: model export requires Neovim (scratch workdir)'
    end
    local workdir = vim.fn.tempname() .. '-unreal-character'
    vim.fn.mkdir(workdir, 'p')
    local blend_path = workdir .. '/character.blend'
    local built, berr = blender_character.build_blend(ch, 'armature3d', blend_path, opts)
    if built == nil then
        vim.fn.delete(workdir, 'rf')
        return nil, berr
    end
    local exported, eerr = blender_character.export_interchange(blend_path, out_path, kind, opts)
    vim.fn.delete(workdir, 'rf')
    if exported == nil then
        return nil, eerr
    end
    return exported, nil
end

---Bake a 2D sprite-sheet PNG + frame manifest for this character via
---the Blender sprites pipeline (games.blender.character
---export_sprite_sheet). Delegates and fails closed when the Blender
---module, Neovim, or the blender binary is unavailable -- there is no
---Unreal-side sprite baker here.
---@param ch table character definition
---@param out_dir string destination directory
---@param opts? { bin?: string, fps?: number, frames?: integer, width?: integer, height?: integer }
---@return { png: string, manifest: string }|nil paths
---@return string|nil err
function M.export_sprite_sheet(ch, out_dir, opts)
    opts = opts or {}
    local has_mod, blender_character = pcall(require, 'games.blender.character')
    if not has_mod then
        return nil, 'unreal: games.blender.character unavailable: ' .. tostring(blender_character)
    end
    return blender_character.export_sprite_sheet(ch, out_dir, opts)
end

---Honest capability report. Import-pipeline hooks only: interchange
---files plus editor stubs as text. 3D is via-interchange, not native.
---@return { dims_2d: boolean, dims_3d: string, notes: string[] }
function M.capabilities()
    return {
        dims_2d = true,
        dims_3d = 'via-interchange',
        notes = {
            'Import-pipeline hooks ONLY: manifest.json + Python editor stub as text artifacts.',
            '2D sprite-sheet PNGs bake via games.blender.character export_sprite_sheet (Blender required).',
            '3D models travel via the Blender interchange pipeline (FBX/glTF); the skeleton is set up in Unreal.',
            'No runtime bridge. Headless Unreal editor scripting cannot be validated in this sandbox;',
            'stubs are starting points, not working integrations.',
        },
    }
end

return M
