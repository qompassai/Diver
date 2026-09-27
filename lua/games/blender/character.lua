-- #################################################################
-- /qompassai/Diver/lua/games/blender/character.lua
-- Qompass AI Blender Character Builder
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
-- Per-character Blender artifacts from a validated shared-character
-- definition.
--
-- 2D: bake frame poses with shared.character.sample_pose(), then build
-- a Blender scene (one textured plane per part, keyframed from the
-- baked poses, orthographic camera) that the games.blender.sprites
-- bake pipeline can render to a sprite strip + frame manifest.
--
-- 3D: build an armature from skeleton.joints (+ optional joints_3d)
-- natively in Blender and keyframe its bones from timeline tracks
-- whose names match joint names (track rot_deg -> bone local Z
-- rotation). Export to glTF/FBX via games.blender.export.
--
-- The generated Python scripts are static text: all parameters travel
-- via environment variables and a JSON spec file, never interpolated
-- into code, so hostile paths cannot break out. Pure at require time;
-- only build_blend()/export_interchange()/export_sprite_sheet() need
-- Neovim + a blender binary, and all three fail closed otherwise.
local kit = require('games.shared.character')

local M = {}

M.FRAMES_MAX = 4096
M.JSON_DEPTH_MAX = 16
M.BINARIES = { 'blender' }
M.ENV_NAMES = { 'BLENDER_BIN', 'NVIM_BLENDER_BIN' }
M.BUILD_TIMEOUT_MS = 600000

---@class BlenderCharacterOpts
---@field bin? string explicit blender binary override
---@field fps? number bake fps override
---@field ortho_scale? number orthographic camera scale (default 6.0)
---@field plane_size? number part plane size in blend units (default 2.0)

---@class BlenderSheetOpts : BlenderSpriteOpts
---@field bin? string explicit blender binary override
---@field fps? number bake fps override
---@field plane_size? number part plane size in blend units (default 2.0)

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
        local key = encode_json(k, depth + 1)
        local item = encode_json(v[k], depth + 1)
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
    local quoted = "'" .. path:gsub("'", "'\\''") .. "'"
    local res = os.execute('test -x ' .. quoted)
    return res == true or res == 0
end

---@param override string|nil
---@return string|nil bin
local function find_binary(override)
    if type(override) == 'string' and override ~= '' and is_executable(override) then
        return override
    end
    for _, env_name in ipairs(M.ENV_NAMES) do
        local from_env = os.getenv(env_name)
        if type(from_env) == 'string' and from_env ~= '' and is_executable(from_env) then
            return from_env
        end
    end
    local path_var = os.getenv('PATH') or ''
    for dir in path_var:gmatch('[^:]+') do
        for _, name in ipairs(M.BINARIES) do
            local candidate = dir .. '/' .. name
            if is_executable(candidate) then
                return candidate
            end
        end
    end
    return nil
end

---Bake every timeline to per-frame part poses with
---shared.character.sample_pose(). Pure.
---@param ch table validated character
---@param opts? { fps?: number }
---@return table|nil manifest { anims = { name = { fps, frames } } }
---@return string|nil err
function M.bake_pose_manifest(ch, opts)
    opts = opts or {}
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, 'blender: invalid character: ' .. tostring(verr[1])
    end
    local anims = {}
    for anim_name, tl in pairs(ch.timelines) do
        local fps = opts.fps or tl.fps
        if type(fps) ~= 'number' or fps <= 0 or fps > kit.FPS_MAX then
            return nil, 'blender: fps out of range'
        end
        local count = math.floor(tl.duration_sec * fps + 1e-9) + 1
        if count > M.FRAMES_MAX then
            return nil, 'blender: frame count exceeds cap'
        end
        local frames = {}
        for i = 1, count do
            local t = math.min((i - 1) / fps, tl.duration_sec)
            local pose, perr = kit.sample_pose(ch, anim_name, t)
            if pose == nil then
                return nil, 'blender: sample_pose failed: ' .. tostring(perr)
            end
            local baked = {}
            for _, part in ipairs(ch.parts) do
                local s = pose[part.name]
                baked[part.name] = {
                    pos = { x = s.pos.x, y = s.pos.y },
                    rot_deg = s.rot_deg,
                    scale = { x = s.scale.x, y = s.scale.y },
                    visible = s.visible,
                }
            end
            frames[i] = { t = t, parts = baked }
        end
        anims[anim_name] = { fps = fps, frames = frames }
    end
    return { format = 'diver-blender-character', version = 1, anims = anims }, nil
end

---Static 2D scene-builder script. Reads the JSON spec from
---DIVER_CHAR_JSON and writes the .blend to DIVER_CHAR_OUT. One
---textured plane per part, keyframed from the baked poses, with a
---fixed orthographic camera matching the sprites-bake preset.
---@return string script
function M.build_2d_script()
    return table.concat({
        'import bpy, json, math, os',
        "spec = json.load(open(os.environ['DIVER_CHAR_JSON']))",
        "out = os.environ['DIVER_CHAR_OUT']",
        'unit = float(os.environ.get("DIVER_CHAR_UNIT", "0.01"))',
        'plane = float(os.environ.get("DIVER_CHAR_PLANE", "2.0"))',
        'ortho = float(os.environ.get("DIVER_CHAR_ORTHO", "6.0"))',
        "bpy.ops.object.select_all(action='SELECT')",
        'bpy.ops.object.delete(use_global=False)',
        "cam_data = bpy.data.cameras.new('DiverCharCam')",
        "cam_data.type = 'ORTHO'",
        'cam_data.ortho_scale = ortho',
        "cam = bpy.data.objects.new('DiverCharCam', cam_data)",
        'bpy.context.scene.collection.objects.link(cam)',
        'cam.location = (0.0, -10.0, 0.0)',
        'cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)',
        'bpy.context.scene.camera = cam',
        'scene = bpy.context.scene',
        'def textured_plane(name, sprite):',
        '    bpy.ops.mesh.primitive_plane_add(size=plane)',
        '    ob = bpy.context.active_object',
        "    ob.name = 'CHAR_' + name",
        "    mat = bpy.data.materials.new('MAT_' + name)",
        '    mat.use_nodes = True',
        "    bsdf = mat.node_tree.nodes['Principled BSDF']",
        "    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')",
        '    tex.image = bpy.data.images.load(sprite)',
        "    mat.node_tree.links.new(bsdf.inputs['Base Color'], tex.outputs['Color'])",
        "    mat.node_tree.links.new(bsdf.inputs['Alpha'], tex.outputs['Alpha'])",
        '    mat.blend_method = "BLEND"',
        '    ob.data.materials.append(mat)',
        '    return ob',
        "for part in spec['parts']:",
        "    ob = textured_plane(part['name'], part['sprite'])",
        "    ob.location = (0.0, 0.0, part['zindex'] * 0.001)",
        "frames = spec['frames']",
        'scene.frame_start = 1',
        'scene.frame_end = len(frames)',
        'for i, frame in enumerate(frames):',
        '    f = i + 1',
        "    for part in spec['parts']:",
        "        ob = bpy.data.objects['CHAR_' + part['name']]",
        "        pose = frame['parts'][part['name']]",
        "        ob.location = (pose['pos']['x'] * unit, -pose['pos']['y'] * unit, part['zindex'] * 0.001)",
        "        ob.rotation_euler = (0.0, 0.0, math.radians(-pose['rot_deg']))",
        "        ob.scale = (pose['scale']['x'], pose['scale']['y'], 1.0)",
        "        ob.hide_viewport = not pose['visible']",
        "        ob.hide_render = not pose['visible']",
        "        ob.keyframe_insert(data_path='location', frame=f)",
        "        ob.keyframe_insert(data_path='rotation_euler', frame=f)",
        "        ob.keyframe_insert(data_path='scale', frame=f)",
        "        ob.keyframe_insert(data_path='hide_viewport', frame=f)",
        "        ob.keyframe_insert(data_path='hide_render', frame=f)",
        'bpy.ops.wm.save_as_mainfile(filepath=out)',
        "print('DIVER_CHAR_OK ' + out)",
    }, '\n') .. '\n'
end

---Static 3D armature-builder script. Reads joints (+ optional
---joints_3d limits, exported for downstream tooling) and baked bone
---rotations from DIVER_CHAR_JSON; writes the .blend to DIVER_CHAR_OUT.
---Bones arrive parent-first in the spec, so parenting never dangles.
---@return string script
function M.build_3d_script()
    return table.concat({
        'import bpy, json, math, os',
        "spec = json.load(open(os.environ['DIVER_CHAR_JSON']))",
        "out = os.environ['DIVER_CHAR_OUT']",
        'unit = float(os.environ.get("DIVER_CHAR_UNIT", "0.01"))',
        "bpy.ops.object.select_all(action='SELECT')",
        'bpy.ops.object.delete(use_global=False)',
        "arm_data = bpy.data.armatures.new('DiverCharArmature')",
        "arm = bpy.data.objects.new('DiverCharArmature', arm_data)",
        'bpy.context.scene.collection.objects.link(arm)',
        'bpy.context.view_layer.objects.active = arm',
        "bpy.ops.object.mode_set(mode='EDIT')",
        'bones = {}',
        "for joint in spec['joints']:",
        "    bone = arm_data.edit_bones.new(joint['name'])",
        "    px, py = joint['pivot']['x'] * unit, joint['pivot']['y'] * unit",
        '    bone.head = (px, 0.0, py)',
        "    length = max(joint['length_px'] * unit, 0.001)",
        '    bone.tail = (px, 0.0, py + length)',
        "    if joint.get('parent'):",
        "        bone.parent = bones[joint['parent']]",
        "    bones[joint['name']] = bone",
        "bpy.ops.object.mode_set(mode='POSE')",
        "frames = spec['bone_frames']",
        'bpy.context.scene.frame_start = 1',
        'bpy.context.scene.frame_end = len(frames)',
        'for i, frame in enumerate(frames):',
        '    f = i + 1',
        "    for name, rot in frame['bones'].items():",
        '        pbone = arm.pose.bones[name]',
        "        pbone.rotation_mode = 'XYZ'",
        '        pbone.rotation_euler = (0.0, 0.0, math.radians(rot))',
        "        pbone.keyframe_insert(data_path='rotation_euler', frame=f)",
        'bpy.ops.wm.save_as_mainfile(filepath=out)',
        "print('DIVER_CHAR_OK ' + out)",
    }, '\n') .. '\n'
end

---Build the argv for `blender -b --python`. Pure: no binary needed.
---Paths travel as argv entries, never interpolated into code.
---@param bin string blender binary path
---@param script_path string generated builder script
---@param blend string|nil .blend to open; nil starts from the default scene
---@return string[]|nil argv
---@return string|nil err
function M.build_argv(bin, script_path, blend)
    if type(bin) ~= 'string' or bin == '' or bin:find('%z') ~= nil then
        return nil, 'blender: bin must be a non-empty path'
    end
    if type(script_path) ~= 'string' or script_path == '' or script_path:find('%z') ~= nil then
        return nil, 'blender: script_path must be a non-empty path'
    end
    if blend ~= nil and (type(blend) ~= 'string' or blend == '' or blend:find('%z') ~= nil) then
        return nil, 'blender: blend must be nil or a non-empty path'
    end
    local argv = { bin, '-b' }
    if blend ~= nil then
        argv[#argv + 1] = blend
    end
    argv[#argv + 1] = '--python'
    argv[#argv + 1] = script_path
    return argv, nil
end

---@param ch table validated character
---@return table|nil spec { parts, frames } for the 2D script
---@return string|nil err
local function build_2d_spec(ch)
    local manifest, merr = M.bake_pose_manifest(ch)
    if manifest == nil then
        return nil, merr
    end
    local anim_names = {}
    for name in pairs(manifest.anims) do
        anim_names[#anim_names + 1] = name
    end
    table.sort(anim_names)
    local anim = manifest.anims[anim_names[1]]
    local parts = {}
    for _, part in ipairs(ch.parts) do
        if type(part.sprite) ~= 'string' or part.sprite == '' then
            return nil, "blender: 2D bake needs a sprite for part '" .. part.name .. "'"
        end
        if part.sprite:sub(1, 1) == '/' or part.sprite:find('%.%.') ~= nil then
            return nil, "blender: unsafe sprite path for part '" .. part.name .. "'"
        end
        parts[#parts + 1] = { name = part.name, zindex = part.zindex, sprite = part.sprite }
    end
    return { parts = parts, frames = anim.frames }, nil
end

---Order joints parent-first (bounded multi-pass; the validator already
---ruled out cycles, so this always terminates).
---@param joints table<string, table>
---@param with_limits boolean include joint limit data
---@return table[] ordered { name, parent, pivot, length_px, limits? }
local function order_joints(joints, with_limits)
    local names = {}
    for name in pairs(joints) do
        names[#names + 1] = name
    end
    table.sort(names)
    local placed, ordered = {}, {}
    for _ = 1, #names + 1 do
        if #ordered == #names then
            break
        end
        for _, name in ipairs(names) do
            if not placed[name] then
                local j = joints[name]
                if j.parent == nil or placed[j.parent] then
                    local entry = { name = name, parent = j.parent, pivot = j.pivot, length_px = j.length_px }
                    if with_limits and j.limits ~= nil then
                        entry.limits = j.limits
                    end
                    ordered[#ordered + 1] = entry
                    placed[name] = true
                end
            end
        end
    end
    return ordered
end

---@param ch table validated character
---@param anim_name string
---@param fps number
---@return table|nil spec { joints, bone_frames } for the 3D script
---@return string|nil err
local function build_3d_spec(ch, anim_name, fps)
    local tl = ch.timelines[anim_name]
    if tl == nil then
        return nil, 'blender: unknown animation ' .. tostring(anim_name)
    end
    local joints = order_joints(ch.skeleton.joints, false)
    if #joints == 0 then
        return nil, 'blender: 3D bake needs at least one skeleton joint'
    end
    if ch.joints_3d ~= nil then
        local joints3 = order_joints(ch.joints_3d, true)
        for i = 1, #joints3 do
            joints[#joints + 1] = joints3[i]
        end
    end
    -- Sample joint-named tracks through the shared sampler by viewing
    -- joints as parts (sample_pose only reads part names + timelines).
    local stubs = {}
    for _, j in ipairs(joints) do
        stubs[#stubs + 1] = { name = j.name }
    end
    local view = { parts = stubs, timelines = ch.timelines }
    local count = math.floor(tl.duration_sec * fps + 1e-9) + 1
    if count > M.FRAMES_MAX then
        return nil, 'blender: frame count exceeds cap'
    end
    local frames = {}
    for i = 1, count do
        local t = math.min((i - 1) / fps, tl.duration_sec)
        local pose, perr = kit.sample_pose(view, anim_name, t)
        if pose == nil then
            return nil, 'blender: sample_pose failed: ' .. tostring(perr)
        end
        local bones = {}
        for _, j in ipairs(joints) do
            local s = pose[j.name]
            bones[j.name] = s ~= nil and s.rot_deg or 0
        end
        frames[i] = { t = t, bones = bones }
    end
    return { joints = joints, bone_frames = frames }, nil
end

---Build the JSON spec for a bake kind. Pure; shared by build_blend
---and tests.
---@param ch table character definition (validated first)
---@param kind string 'pose2d' | 'armature3d'
---@param opts? BlenderCharacterOpts
---@return table|nil spec
---@return string|nil err
function M.build_spec(ch, kind, opts)
    opts = opts or {}
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, 'blender: invalid character: ' .. tostring(verr[1])
    end
    if kind == 'pose2d' then
        return build_2d_spec(ch)
    end
    if kind == 'armature3d' then
        local anim_names = {}
        for name in pairs(ch.timelines) do
            anim_names[#anim_names + 1] = name
        end
        table.sort(anim_names)
        if #anim_names == 0 then
            return nil, 'blender: character has no timelines to bake'
        end
        local fps = opts.fps or ch.timelines[anim_names[1]].fps
        return build_3d_spec(ch, anim_names[1], fps)
    end
    return nil, "blender: unknown kind '" .. tostring(kind) .. "'"
end

---@param kind string
---@return string|nil script
local function script_for_kind(kind)
    if kind == 'pose2d' then
        return M.build_2d_script()
    end
    if kind == 'armature3d' then
        return M.build_3d_script()
    end
    return nil
end

---Build a .blend from a character: write the JSON spec + static
---builder script to a workdir, then run `blender -b --python`.
---Fails closed: needs Neovim (vim.system) and a blender binary.
---@param ch table character definition
---@param kind string 'pose2d' | 'armature3d'
---@param blend_path string destination .blend path
---@param opts? BlenderCharacterOpts
---@return string|nil blend_path
---@return string|nil err
function M.build_blend(ch, kind, blend_path, opts)
    opts = opts or {}
    if type(blend_path) ~= 'string' or blend_path == '' or blend_path:find('%z') ~= nil then
        return nil, 'blender: blend_path must be a non-empty path'
    end
    local spec, serr = M.build_spec(ch, kind, opts)
    if spec == nil then
        return nil, serr
    end
    local script = script_for_kind(kind)
    if script == nil then
        return nil, "blender: unknown kind '" .. tostring(kind) .. "'"
    end
    local bin = find_binary(opts.bin)
    if bin == nil then
        return nil, 'blender: binary not found (tried BLENDER_BIN/NVIM_BLENDER_BIN and PATH); cannot build .blend'
    end
    if vim == nil or vim.fn == nil or vim.system == nil then
        return nil, 'blender: executing the builder requires Neovim (vim.system); spec generation works anywhere'
    end
    local spec_json = encode_json(spec, 0)
    if spec_json == nil then
        return nil, 'blender: spec is not JSON-serializable'
    end
    local workdir = vim.fn.tempname() .. '-blender-character'
    vim.fn.mkdir(workdir, 'p')
    local json_path = workdir .. '/spec.json'
    local script_path = workdir .. '/build.py'
    if vim.fn.writefile({ spec_json }, json_path) ~= 0 then
        vim.fn.delete(workdir, 'rf')
        return nil, 'blender: could not write spec JSON'
    end
    if vim.fn.writefile(vim.split(script, '\n', { plain = true }), script_path) ~= 0 then
        vim.fn.delete(workdir, 'rf')
        return nil, 'blender: could not write builder script'
    end
    local argv, aerr = M.build_argv(bin, script_path, nil)
    if argv == nil then
        vim.fn.delete(workdir, 'rf')
        return nil, aerr
    end
    local ortho = opts.ortho_scale or 6.0
    local plane = opts.plane_size or 2.0
    local completed = vim.system(argv, {
        text = true,
        timeout = M.BUILD_TIMEOUT_MS,
        env = {
            DIVER_CHAR_JSON = json_path,
            DIVER_CHAR_OUT = blend_path,
            DIVER_CHAR_ORTHO = tostring(ortho),
            DIVER_CHAR_PLANE = tostring(plane),
        },
    }):wait()
    vim.fn.delete(workdir, 'rf')
    if completed.code ~= 0 then
        local detail = (completed.stderr or ''):match('^([^\r\n]*)') or ''
        return nil, ('blender: builder failed (exit %d): %s'):format(completed.code, detail)
    end
    local out = completed.stdout or ''
    if not out:find('DIVER_CHAR_OK', 1, true) then
        return nil, 'blender: builder did not report success'
    end
    return blend_path, nil
end

---Export a built .blend to an interchange file via
---games.blender.export (glb/fbx). Fails closed when the export
---module or the blender binary is unavailable.
---@param blend_path string source .blend
---@param out_path string destination file
---@param kind string 'glb' | 'fbx'
---@param opts? BlenderCharacterOpts
---@return string|nil out_path
---@return string|nil err
function M.export_interchange(blend_path, out_path, kind, opts)
    opts = opts or {}
    if kind ~= 'glb' and kind ~= 'fbx' then
        return nil, "blender: kind must be 'glb' or 'fbx'"
    end
    if type(blend_path) ~= 'string' or blend_path == '' then
        return nil, 'blender: blend_path required'
    end
    if type(out_path) ~= 'string' or out_path == '' then
        return nil, 'blender: out_path required'
    end
    if find_binary(opts.bin) == nil then
        return nil, 'blender: binary not found; cannot export interchange files'
    end
    local has_mod, exporter = pcall(require, 'games.blender.export')
    if not has_mod then
        return nil, 'blender: games.blender.export unavailable: ' .. tostring(exporter)
    end
    if kind == 'glb' then
        return exporter.export_glb(blend_path, out_path)
    end
    return exporter.export_fbx(blend_path, out_path)
end

---Bake a 2D sprite strip PNG + JSON frame manifest for a character:
---build the pose2d .blend, then render it through the
---games.blender.sprites bake pipeline. Fails closed when the sprites
---module, Neovim, or the blender binary is unavailable.
---@param ch table character definition
---@param out_dir string destination directory
---@param opts? BlenderSheetOpts
---@return { png: string, manifest: string }|nil paths
---@return string|nil err
function M.export_sprite_sheet(ch, out_dir, opts)
    opts = opts or {}
    if type(out_dir) ~= 'string' or out_dir == '' or out_dir:find('%z') ~= nil then
        return nil, 'blender: out_dir must be a non-empty path'
    end
    if find_binary(opts.bin) == nil then
        return nil, 'blender: binary not found (tried BLENDER_BIN/NVIM_BLENDER_BIN and PATH); cannot bake sprite sheet'
    end
    local has_mod, sprites = pcall(require, 'games.blender.sprites')
    if not has_mod then
        return nil, 'blender: games.blender.sprites unavailable: ' .. tostring(sprites)
    end
    local blend_path = out_dir .. '/character.blend'
    local built, berr = M.build_blend(ch, 'pose2d', blend_path, {
        bin = opts.bin,
        fps = opts.fps,
        ortho_scale = opts.ortho_scale,
        plane_size = opts.plane_size,
    })
    if built == nil then
        return nil, berr
    end
    local png = out_dir .. '/sheet.png'
    local manifest = out_dir .. '/sheet.json'
    local baked, bake_err = sprites.bake(built, png, manifest, opts)
    if baked == nil then
        return nil, bake_err
    end
    return { png = png, manifest = manifest }, nil
end

---Honest capability report. Both dimensions are native Blender:
---2D via the sprites-bake pipeline, 3D via a real armature.
---@return { dims_2d: boolean, dims_3d: boolean, notes: string[] }
function M.capabilities()
    return {
        dims_2d = true,
        dims_3d = true,
        notes = {
            '2D: keyframed textured planes + orthographic camera; rendered via games.blender.sprites bake.',
            '3D: native armature built from skeleton.joints + joints_3d, keyframed from joint-named tracks.',
            'Builder scripts are static text; paths travel via env/JSON, never interpolated into code.',
            'glTF/FBX export goes through games.blender.export.',
        },
    }
end

return M
