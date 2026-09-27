-- #################################################################
-- /qompassai/Diver/lua/games/godot/character.lua
-- Qompass AI Godot Character Builder
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
-- Per-character Godot interchange artifacts from a validated
-- shared-character definition.
--
-- 2D: a JSON frame manifest (poses baked with
-- shared.character.sample_pose()) + a .tscn sketch + a GDScript import
-- stub the engine can consume. 3D: skeletal via the Blender glTF
-- pipeline -- build with games.blender.character (build_blend kind
-- 'armature3d', then export_interchange 'glb') and import the .glb in
-- Godot; that path is documented here, not automated.
--
-- Honest limits: headless Godot import validation is limited in this
-- sandbox. validate_project() fails closed with a clear error when the
-- engine binary is absent, and only probes `--version` when present --
-- full scene import still needs the editor. Pure at require time.
local kit = require('games.shared.character')

local M = {}

M.FRAMES_MAX = 4096
M.JSON_DEPTH_MAX = 16
M.NAME_LEN_MAX = 48
M.PROBE_TIMEOUT_MS = 30000

local ENGINE = {
    display = 'Godot',
    binaries = { 'godot4', 'godot', 'Godot', 'Godot_v4' },
    env_names = { 'NVIM_GODOT_BIN', 'GODOT_BIN', 'GODOT4_BIN' },
    manifest_format = 'diver-character-godot',
}

---@class GodotCharacterOpts
---@field bin? string explicit engine binary override
---@field fps? number bake fps override
---@field name? string character name override (sanitized)

---@class GodotInterchangeFile
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

---@param path string
---@return boolean
local function is_executable(path)
    if type(path) ~= 'string' or path == '' or path:find('%z') ~= nil then
        return false
    end
    if vim ~= nil and vim.fn ~= nil and vim.fn.executable ~= nil then
        return vim.fn.executable(path) == 1
    end
    local probe = io.open(path, 'rb')
    if probe == nil then
        return false
    end
    probe:close()
    local res = os.execute('test -x ' .. "'" .. path:gsub("'", "'\\''") .. "'")
    return res == true or res == 0
end

---@param override string|nil
---@return string|nil bin
local function find_binary(override)
    if type(override) == 'string' and override ~= '' and is_executable(override) then
        return override
    end
    for _, env_name in ipairs(ENGINE.env_names) do
        local from_env = os.getenv(env_name)
        if type(from_env) == 'string' and from_env ~= '' and is_executable(from_env) then
            return from_env
        end
    end
    local path_var = os.getenv('PATH') or ''
    for dir in path_var:gmatch('[^:]+') do
        for _, name in ipairs(ENGINE.binaries) do
            local candidate = dir .. '/' .. name
            if is_executable(candidate) then
                return candidate
            end
        end
    end
    return nil
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

---Escape a part name for a double-quoted .tscn attribute. Kit names may
---contain quotes, tabs and newlines (only NUL is rejected), so raw
---interpolation would allow attribute breakout.
---@param s string
---@return string
local function tscn_escape(s)
    return (tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t'))
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
        return nil, ENGINE.display .. ": unsafe sprite path for part '" .. part_name .. "'"
    end
    return sprite, nil
end

---@param ch table validated character
---@param opts? GodotCharacterOpts
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
            return nil, ENGINE.display .. ': fps out of range'
        end
        local count = math.floor(tl.duration_sec * fps + 1e-9) + 1
        if count > M.FRAMES_MAX then
            return nil, ENGINE.display .. ': frame count exceeds cap'
        end
        local frames = {}
        for i = 1, count do
            local t = math.min((i - 1) / fps, tl.duration_sec)
            local pose, perr = kit.sample_pose(ch, anim_name, t)
            if pose == nil then
                return nil, ENGINE.display .. ': sample_pose failed: ' .. tostring(perr)
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
        format = ENGINE.manifest_format,
        version = 1,
        character = ch.name,
        parts = parts,
        anims = anims,
    },
        nil
end

---@param ch table validated character
---@param safe string sanitized character name
---@return string tscn sketch text
local function build_tscn(ch, safe)
    local lines = {
        '; Generated by diver games/godot/character.lua -- .tscn sketch.',
        '; Import manifest.json with import_' .. safe .. '.gd to build the real scene.',
        '[gd_scene load_steps=2 format=3]',
        '',
        '[node name="' .. safe .. '" type="Node2D"]',
        '',
    }
    local ordered = {}
    for _, part in ipairs(ch.parts) do
        ordered[#ordered + 1] = part
    end
    table.sort(ordered, function(a, b)
        return a.zindex < b.zindex
    end)
    for _, part in ipairs(ordered) do
        lines[#lines + 1] = '[node name="' .. tscn_escape(part.name) .. '" type="Sprite2D" parent="."]'
        lines[#lines + 1] = 'z_index = ' .. tostring(part.zindex)
        lines[#lines + 1] = 'position = Vector2(' .. part.anchor.x .. ', ' .. part.anchor.y .. ')'
        lines[#lines + 1] = ''
    end
    lines[#lines + 1] = '[node name="AnimationPlayer" type="AnimationPlayer" parent="."]'
    lines[#lines + 1] = ''
    return table.concat(lines, '\n')
end

local GD_TEMPLATE = [==[
@tool
extends EditorScript
# Generated by diver games/godot/character.lua -- IMPORT STUB, a starting
# point, not a working integration. Reads manifest.json next to this script,
# creates one Sprite2D per part under a Node2D root, and builds one
# Animation per timeline on an AnimationPlayer from the baked frames.
# Run from the Godot script editor: File -> Run.
func _run() -> void:
    var base := (get_script() as Script).resource_path.get_base_dir()
    var manifest_path := base.path_join("manifest.json")
    var text := FileAccess.get_file_as_string(manifest_path)
    var parsed := JSON.parse_string(text)
    if parsed == null:
        push_error("diver: cannot parse " + manifest_path)
        return
    var root := Node2D.new()
    root.name = str(parsed.get("character", "character"))
    get_editor_interface().get_edited_scene_root().add_child(root)
    root.set_owner(get_editor_interface().get_edited_scene_root())
    var player := AnimationPlayer.new()
    player.name = "AnimationPlayer"
    root.add_child(player)
    player.set_owner(root)
    var parts: Array = parsed.get("parts", [])
    for part in parts:
        var sprite := Sprite2D.new()
        sprite.name = str(part["name"])
        var anchor: Array = part["anchor"]
        sprite.position = Vector2(float(anchor[0]), float(anchor[1]))
        sprite.z_index = int(part["zindex"])
        var sprite_path = part.get("sprite", null)
        if sprite_path != null:
            sprite.texture = load(base.path_join("sprites").path_join(str(sprite_path)))
        root.add_child(sprite)
        sprite.set_owner(root)
    var anims: Dictionary = parsed.get("anims", {})
    for anim_name in anims:
        var spec: Dictionary = anims[anim_name]
        var animation := Animation.new()
        var fps := float(spec.get("fps", 12.0))
        animation.step = 1.0 / fps
        var frames: Array = spec.get("frames", [])
        for i in frames.size():
            var pose: Dictionary = frames[i]["parts"]
            for part_name in pose:
                var sample: Dictionary = pose[part_name]
                var node_path := NodePath(str(part_name))
                var pos: Array = sample["pos"]
                var track := animation.add_track(Animation.TYPE_VALUE)
                animation.track_set_path(track, node_path + ":position")
                animation.track_insert_key(track, float(i) / fps, Vector2(float(pos[0]), float(pos[1])))
        var loop = spec.get("loop", false)
        if loop == true:
            animation.loop_mode = Animation.LOOP_LINEAR
        elif str(loop) == "pingpong":
            animation.loop_mode = Animation.LOOP_PINGPONG
        player.add_animation_library("diver", AnimationLibrary.new())
        player.get_animation_library("diver").add_animation(str(anim_name), animation)
    print("diver: imported character stub for ", root.name)
]==]

---Build the 2D interchange set: manifest.json + .tscn sketch +
---GDScript import stub. Validates first; hostile definitions are
---rejected with nil, err before any artifact text is produced.
---@param ch table character definition
---@param opts? GodotCharacterOpts
---@return { files: GodotInterchangeFile[] }|nil bundle
---@return string|nil err
function M.build_interchange(ch, opts)
    opts = opts or {}
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, ENGINE.display .. ': invalid character: ' .. tostring(verr[1])
    end
    if next(ch.timelines) == nil then
        return nil, ENGINE.display .. ': character has no timelines to bake'
    end
    local safe = sanitize_name(opts.name or ch.name)
    local manifest, merr = build_manifest(ch, opts)
    if manifest == nil then
        return nil, merr
    end
    local encoded = encode_json(manifest, 0)
    if encoded == nil then
        return nil, ENGINE.display .. ': manifest is not JSON-serializable'
    end
    return {
        files = {
            { path = 'manifest.json', content = encoded .. '\n' },
            { path = safe .. '.tscn', content = build_tscn(ch, safe) },
            { path = 'import_' .. safe .. '.gd', content = GD_TEMPLATE },
        },
    },
        nil
end

---Probe a Godot project directory. Fails closed when the engine binary
---is absent; when present, only runs `--headless --version` as a
---sanity probe -- full scene import validation needs the editor and is
---explicitly out of scope here.
---@param project_dir string directory containing project.godot
---@param opts? GodotCharacterOpts
---@return string|nil version probe output
---@return string|nil err
function M.validate_project(project_dir, opts)
    opts = opts or {}
    if type(project_dir) ~= 'string' or project_dir == '' then
        return nil, ENGINE.display .. ': project_dir required'
    end
    local marker = io.open(project_dir .. '/project.godot', 'r')
    if marker == nil then
        return nil, ENGINE.display .. ': no project.godot in ' .. project_dir
    end
    marker:close()
    local bin = find_binary(opts.bin)
    if bin == nil then
        return nil,
            ENGINE.display
                .. ': engine binary not found (tried '
                .. table.concat(ENGINE.binaries, ', ')
                .. '); headless import validation unavailable in this environment'
    end
    if vim == nil or vim.system == nil then
        return nil, ENGINE.display .. ': probing the engine binary requires Neovim (vim.system)'
    end
    local completed = vim.system({ bin, '--headless', '--version' }, {
        text = true,
        timeout = M.PROBE_TIMEOUT_MS,
    }):wait()
    if completed.code ~= 0 then
        return nil, ENGINE.display .. ': engine probe failed (exit ' .. completed.code .. ')'
    end
    return (completed.stdout or ''):match('^([^\r\n]*)') or '', nil
end

---Bake a 2D sprite-sheet PNG + frame manifest for this character via
---the Blender sprites pipeline (games.blender.character
---export_sprite_sheet). Delegates and fails closed when the Blender
---module, Neovim, or the blender binary is unavailable -- there is no
---Godot-side sprite baker here.
---@param ch table character definition
---@param out_dir string destination directory
---@param opts? { bin?: string, fps?: number, frames?: integer, width?: integer, height?: integer }
---@return { png: string, manifest: string }|nil paths
---@return string|nil err
function M.export_sprite_sheet(ch, out_dir, opts)
    opts = opts or {}
    local has_mod, blender_character = pcall(require, 'games.blender.character')
    if not has_mod then
        return nil, ENGINE.display .. ': games.blender.character unavailable: ' .. tostring(blender_character)
    end
    return blender_character.export_sprite_sheet(ch, out_dir, opts)
end

---Honest capability report. 2D is emitted artifacts; 3D is
---via-interchange through the Blender glTF pipeline, not native here.
---@return { dims_2d: boolean, dims_3d: string, notes: string[] }
function M.capabilities()
    return {
        dims_2d = true,
        dims_3d = 'via-interchange',
        notes = {
            '2D: emits manifest.json + .tscn sketch + GDScript import stub.',
            'The stub is a starting point, not a working integration.',
            '2D sprite-sheet PNGs bake via games.blender.character export_sprite_sheet (Blender required).',
            '3D: skeletal via the Blender glTF pipeline (games.blender.character',
            'build_blend + export glb); import the .glb in Godot.',
            'Headless Godot import validation is limited in this sandbox;',
            'validate_project() fails closed without the engine binary.',
        },
    }
end

return M
