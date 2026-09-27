-- #################################################################
-- /qompassai/Diver/lua/games/shared/character.lua
-- Qompass AI Games Shared Character Kit
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
-- Engine-neutral character definition kit: named parts with anchors,
-- palette recolor maps, keyframed timelines, and a 2D bone skeleton
-- (plus a data-only 3D joint extension), with a timeline pose sampler.
--
-- Pure logic: no vim.* at require time, no engine claims. Runs under
-- Lua 5.4, LuaJIT, and inside Neovim. Per-engine modules (a later track
-- writes lua/games/<engine>/character.lua) consume sample_pose(); this
-- module never touches a renderer.
--
-- Data model (all shapes documented with LuaCATS below):
--   Character: { name, version, parts, palettes, timelines, skeleton }
--   parts: array of { name, anchor={x,y} px pivot, zindex, sprite, tags }
--   palettes: { name -> { colors={hex}, map={from_hex->to_hex} } }
--   timelines: { anim -> { loop, fps, duration_sec, tracks } }
--     loop is true (wrap) | 'pingpong' (mirror) | false (clamp)
--     tracks: { part_name -> array of keyframes, non-decreasing t }
--     keyframe: { t, pos={x,y}?, rot_deg?, scale={x,y}?, visible? }
--   skeleton: { joints={ name -> joint }, root=name }
--     joint: { parent=name|nil, pivot={x,y}, rot_min_deg, rot_max_deg,
--              length_px }
--   joints_3d (optional): { name -> { parent, limits={pitch,yaw,roll} } }
--     each limit is a {min, max} pair in degrees. DATA ONLY -- this kit
--     makes no claim about any engine's bone or rig semantics.
--
-- Contracts: builder functions (new_character, add_*, set_keyframe)
-- assert their contracts (types, ranges, unique names, named bounds).
-- validate_character() is the pure checker for untrusted data; it never
-- raises. from_table() validates first and returns nil, err on hostile
-- shapes. sample_pose() returns nil, err on bad input.
local M = {}

---Schema version written by new_character/to_table. Bump when the
---shape changes; from_table rejects anything else.
M.VERSION = 1

-- Named bounds. Every collection and numeric field is capped; the
-- builder asserts these, the validator reports them.
M.PARTS_MAX = 256
M.PALETTES_MAX = 32
M.PALETTE_COLORS_MAX = 256
M.TIMELINES_MAX = 64
M.KEYFRAMES_MAX = 4096
M.JOINTS_MAX = 256
M.JOINTS_3D_MAX = 256
M.NAME_LEN_MAX = 64
M.TAGS_MAX = 16
M.SPRITE_PATH_LEN_MAX = 512
M.FPS_MAX = 240
M.DURATION_SEC_MAX = 3600
M.COORD_PX_MAX = 4096
M.ZINDEX_MIN = -9999
M.ZINDEX_MAX = 9999
M.SCALE_MIN = 0.001
M.SCALE_MAX = 100.0
M.ROT_DEG_ABS_MAX = 1080
M.JOINT3D_DEG_ABS_MAX = 180

---@class CharVec2
---@field x number
---@field y number

---@class CharacterPart
---@field name string unique within the character
---@field anchor CharVec2 pivot in part-local pixels
---@field zindex number integer-valued, ZINDEX_MIN..ZINDEX_MAX
---@field sprite string|nil asset path, or nil when unassigned
---@field tags string[] free-form labels, TAGS_MAX at most

---@class CharacterPalette
---@field colors string[] '#rrggbb' hex strings
---@field map table<string,string> from_hex -> to_hex recolor pairs

---@class Keyframe
---@field t number seconds, finite and >= 0
---@field pos CharVec2|nil offset in pixels
---@field rot_deg number|nil rotation in degrees
---@field scale CharVec2|nil scale factors; sign mirrors, magnitude in SCALE_MIN..SCALE_MAX
---@field visible boolean|nil visibility; snaps at keyframe times (no blending)

---@class Timeline
---@field loop boolean|'pingpong' true wraps, 'pingpong' mirrors, false clamps
---@field fps number frames per second, (0, FPS_MAX]
---@field duration_sec number (0, DURATION_SEC_MAX]
---@field tracks table<string, Keyframe[]> part name -> keyframes, non-decreasing t

---@class Joint
---@field parent string|nil parent joint name; nil marks a root candidate
---@field pivot CharVec2 pivot in pixels
---@field rot_min_deg number minimum rotation, -ROT_DEG_ABS_MAX..ROT_DEG_ABS_MAX
---@field rot_max_deg number maximum rotation, >= rot_min_deg
---@field length_px number bone length, 0..COORD_PX_MAX

---@class Joint3DLimits
---@field pitch number[] {min, max} pair in degrees
---@field yaw number[] {min, max} pair in degrees
---@field roll number[] {min, max} pair in degrees

---@class Joint3D
---@field parent string|nil parent 3D joint name, or nil
---@field limits Joint3DLimits per-axis {min, max} degree pairs

---@class Skeleton
---@field joints table<string, Joint> joint name -> joint
---@field root string joint name, or '' while no joints exist

---@class Character
---@field name string
---@field version integer schema version (M.VERSION)
---@field parts CharacterPart[] declared parts, unique names
---@field palettes table<string, CharacterPalette> palette name -> palette
---@field timelines table<string, Timeline> animation name -> timeline
---@field skeleton Skeleton 2D bone data
---@field joints_3d table<string, Joint3D>|nil optional 3D joint data

---@class PartSpec
---@field name string
---@field anchor CharVec2
---@field zindex number integer-valued
---@field sprite string|nil
---@field tags string[]|nil defaults to {}

---@class PaletteSpec
---@field name string
---@field colors string[]
---@field map table<string,string>|nil defaults to {}

---@class TimelineSpec
---@field loop boolean|'pingpong'
---@field fps number
---@field duration_sec number

---@class JointSpec
---@field name string
---@field parent string|nil nil for the first joint; otherwise must name an existing joint
---@field pivot CharVec2
---@field rot_min_deg number
---@field rot_max_deg number
---@field length_px number

---@class Joint3DSpec
---@field name string
---@field parent string|nil nil, or the name of an existing 3D joint
---@field limits Joint3DLimits

---@class SampledPart
---@field pos CharVec2 resolved offset in pixels
---@field rot_deg number resolved rotation in degrees
---@field scale CharVec2 resolved scale factors
---@field visible boolean resolved visibility

-- ============ private leaf helpers ============

---@param v unknown
---@return boolean
local function is_finite_number(v)
    if type(v) ~= 'number' then
        return false
    end
    return v == v and math.abs(v) ~= math.huge
end

---@param v unknown
---@return boolean
local function is_integer_valued(v)
    if type(v) ~= 'number' then
        return false
    end
    if v ~= v or math.abs(v) == math.huge then
        return false
    end
    return v == math.floor(v)
end

---@param s unknown
---@return boolean
local function is_valid_name(s)
    if type(s) ~= 'string' then
        return false
    end
    if #s < 1 or #s > M.NAME_LEN_MAX then
        return false
    end
    return s:find('%z') == nil
end

---@param s unknown
---@return boolean
local function is_valid_hex(s)
    if type(s) ~= 'string' then
        return false
    end
    return s:find('^#%x%x%x%x%x%x$') ~= nil
end

---Validate a {x, y} table against [lo, hi]. Returns an error string,
---or nil when valid. Rejects nil (callers gate optional fields).
---@param v unknown
---@param lo number
---@param hi number
---@param what string field label for messages
---@return string|nil err
local function check_vec2(v, lo, hi, what)
    if type(v) ~= 'table' then
        return what .. ' must be {x, y}'
    end
    local x, y = v.x, v.y
    if not is_finite_number(x) or x < lo or x > hi then
        return what .. '.x out of range'
    end
    if not is_finite_number(y) or y < lo or y > hi then
        return what .. '.y out of range'
    end
    return nil
end

---Validate a scale {x, y}: each component finite, magnitude in
---[SCALE_MIN, SCALE_MAX]. Negative components mirror; that is allowed.
---@param v unknown
---@param what string field label for messages
---@return string|nil err
local function check_scale_vec2(v, what)
    if type(v) ~= 'table' then
        return what .. ' must be {x, y}'
    end
    for _, axis in ipairs({ 'x', 'y' }) do
        local c = v[axis]
        if not is_finite_number(c) then
            return what .. '.' .. axis .. ' must be a finite number'
        end
        local mag = math.abs(c)
        if mag < M.SCALE_MIN or mag > M.SCALE_MAX then
            return what .. '.' .. axis .. ' magnitude out of range'
        end
    end
    return nil
end

---@param v CharVec2
---@return CharVec2
local function copy_vec2(v)
    return { x = v.x, y = v.y }
end

---@param arr string[]
---@return string[]
local function copy_string_array(arr)
    local out = {}
    for i = 1, #arr do
        out[i] = arr[i]
    end
    return out
end

---@param map table<string, any>
---@return string[] keys in sorted order
local function sorted_keys(map)
    local keys = {}
    for k in pairs(map) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

---Bounded array length: at most bound + 1 probes, so hostile tables
---with millions of entries are rejected without a full scan.
---@param t table
---@param bound integer
---@return integer n length, or bound + 1 when longer
---@return boolean over true when the array exceeds bound
local function array_len_bounded(t, bound)
    for i = 1, bound + 1 do
        if t[i] == nil then
            return i - 1, false
        end
    end
    return bound + 1, true
end

---@param t table
---@param bound integer
---@return boolean over true when the map exceeds bound entries
local function map_over_bound(t, bound)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
        if n > bound then
            return true
        end
    end
    return false
end

---Iterative cycle hunt over joint parent links. Returns the joint name
---where a cycle (or an impossibly deep chain) was found, else nil.
---Bounded: at most bound + 1 hops per start joint, no recursion.
---@param joints table<string, any> each value has a .parent field
---@param bound integer max joints allowed
---@return string|nil cycle_at
local function find_joint_cycle(joints, bound)
    for _, start in ipairs(sorted_keys(joints)) do
        local seen = {}
        local cur = start
        local steps = 0
        while cur ~= nil do
            steps = steps + 1
            if steps > bound + 1 then
                return start
            end
            if seen[cur] then
                return start
            end
            seen[cur] = true
            local j = joints[cur]
            if type(j) ~= 'table' then
                break
            end
            local parent = j.parent
            if parent == nil or type(parent) ~= 'string' then
                break
            end
            cur = parent
        end
    end
    return nil
end

---@param ch Character
local function assert_is_character(ch)
    assert(type(ch) == 'table', 'character table required')
    assert(ch.version == M.VERSION, 'unsupported character version')
    assert(type(ch.parts) == 'table', 'character.parts must be an array')
    assert(type(ch.palettes) == 'table', 'character.palettes must be a map')
    assert(type(ch.timelines) == 'table', 'character.timelines must be a map')
    assert(type(ch.skeleton) == 'table', 'character.skeleton required')
    assert(type(ch.skeleton.joints) == 'table', 'character.skeleton.joints must be a map')
end

---@param ch Character
---@param name string
---@return CharacterPart|nil
local function part_by_name(ch, name)
    for i = 1, #ch.parts do
        if ch.parts[i].name == name then
            return ch.parts[i]
        end
    end
    return nil
end

---@param kf Keyframe
---@return Keyframe stored copy (never aliases the caller's table)
local function copy_keyframe(kf)
    local out = { t = kf.t }
    if kf.pos ~= nil then
        out.pos = copy_vec2(kf.pos)
    end
    if kf.rot_deg ~= nil then
        out.rot_deg = kf.rot_deg
    end
    if kf.scale ~= nil then
        out.scale = copy_vec2(kf.scale)
    end
    if kf.visible ~= nil then
        out.visible = kf.visible
    end
    return out
end

---Assert a keyframe's fields (called after t is known good).
---@param kf Keyframe
local function check_keyframe_fields(kf)
    for field in pairs(kf) do
        assert(
            field == 't' or field == 'pos' or field == 'rot_deg' or field == 'scale' or field == 'visible',
            "unexpected keyframe field '" .. tostring(field) .. "'"
        )
    end
    if kf.pos ~= nil then
        local err = check_vec2(kf.pos, -M.COORD_PX_MAX, M.COORD_PX_MAX, 'keyframe pos')
        assert(err == nil, err or 'bad keyframe pos')
    end
    if kf.scale ~= nil then
        local err = check_scale_vec2(kf.scale, 'keyframe scale')
        assert(err == nil, err or 'bad keyframe scale')
    end
    assert(
        kf.rot_deg == nil
            or (is_finite_number(kf.rot_deg) and kf.rot_deg >= -M.ROT_DEG_ABS_MAX and kf.rot_deg <= M.ROT_DEG_ABS_MAX),
        'keyframe rot_deg out of range'
    )
    assert(kf.visible == nil or type(kf.visible) == 'boolean', 'keyframe visible must be boolean')
end

---Assert 3D joint limits and return a copied Joint3DLimits.
---@param limits unknown
---@return Joint3DLimits
local function check_axis_limits(limits)
    assert(type(limits) == 'table', '3d joint limits table required')
    local out = {}
    for _, axis in ipairs({ 'pitch', 'yaw', 'roll' }) do
        local pair = limits[axis]
        assert(type(pair) == 'table', "limits.'" .. axis .. "' must be a {min, max} pair")
        assert(pair[3] == nil, "limits.'" .. axis .. "' must have exactly 2 entries")
        local lo, hi = pair[1], pair[2]
        assert(
            is_finite_number(lo) and lo >= -M.JOINT3D_DEG_ABS_MAX and lo <= M.JOINT3D_DEG_ABS_MAX,
            "limits.'" .. axis .. "'[1] out of range"
        )
        assert(
            is_finite_number(hi) and hi >= -M.JOINT3D_DEG_ABS_MAX and hi <= M.JOINT3D_DEG_ABS_MAX,
            "limits.'" .. axis .. "'[2] out of range"
        )
        assert(lo <= hi, "limits.'" .. axis .. "' min must not exceed max")
        out[axis] = { lo, hi }
    end
    return out
end

-- ============ builder API ============

---Create an empty character definition.
---@param name string 1..NAME_LEN_MAX chars, no NUL bytes
---@return Character
function M.new_character(name)
    assert(is_valid_name(name), 'character name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    return {
        name = name,
        version = M.VERSION,
        parts = {},
        palettes = {},
        timelines = {},
        skeleton = { joints = {}, root = '' },
    }
end

---Add a named part. Names are unique per character; anchor and tags
---are copied so the caller's tables never alias the character.
---@param ch Character
---@param spec PartSpec
---@return CharacterPart part
function M.add_part(ch, spec)
    assert_is_character(ch)
    assert(type(spec) == 'table', 'part spec table required')
    local name = spec.name
    assert(is_valid_name(name), 'part name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    assert(#ch.parts < M.PARTS_MAX, 'too many parts (max ' .. M.PARTS_MAX .. ')')
    assert(part_by_name(ch, name) == nil, "duplicate part name '" .. tostring(name) .. "'")
    local anchor_err = check_vec2(spec.anchor, -M.COORD_PX_MAX, M.COORD_PX_MAX, 'part anchor')
    assert(anchor_err == nil, anchor_err or 'bad part anchor')
    local zindex = spec.zindex
    assert(
        is_integer_valued(zindex) and zindex >= M.ZINDEX_MIN and zindex <= M.ZINDEX_MAX,
        'zindex must be an integer in [' .. M.ZINDEX_MIN .. ', ' .. M.ZINDEX_MAX .. ']'
    )
    local sprite = spec.sprite
    assert(
        sprite == nil or (type(sprite) == 'string' and #sprite >= 1 and #sprite <= M.SPRITE_PATH_LEN_MAX),
        'sprite must be nil or a path of 1..' .. M.SPRITE_PATH_LEN_MAX .. ' chars'
    )
    assert(spec.tags == nil or type(spec.tags) == 'table', 'part tags must be an array of names')
    local tags_in = spec.tags or {}
    local tags_n, tags_over = array_len_bounded(tags_in, M.TAGS_MAX)
    assert(not tags_over, 'too many tags (max ' .. M.TAGS_MAX .. ')')
    local tags = {}
    for i = 1, tags_n do
        local tag = tags_in[i]
        assert(is_valid_name(tag), 'tag #' .. i .. ' must be 1..' .. M.NAME_LEN_MAX .. ' chars')
        tags[i] = tag
    end
    local part = {
        name = name,
        anchor = copy_vec2(spec.anchor),
        zindex = zindex,
        sprite = sprite,
        tags = tags,
    }
    ch.parts[#ch.parts + 1] = part
    return part
end

---Add a named palette with a hex color list and an optional
---from_hex -> to_hex recolor map. Names are unique per character.
---@param ch Character
---@param spec PaletteSpec
---@return CharacterPalette palette
function M.add_palette(ch, spec)
    assert_is_character(ch)
    assert(type(spec) == 'table', 'palette spec table required')
    local name = spec.name
    assert(is_valid_name(name), 'palette name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    assert(ch.palettes[name] == nil, "duplicate palette name '" .. tostring(name) .. "'")
    assert(not map_over_bound(ch.palettes, M.PALETTES_MAX), 'too many palettes (max ' .. M.PALETTES_MAX .. ')')
    assert(type(spec.colors) == 'table', 'palette colors must be an array of hex strings')
    local colors_n, colors_over = array_len_bounded(spec.colors, M.PALETTE_COLORS_MAX)
    assert(not colors_over, 'too many colors (max ' .. M.PALETTE_COLORS_MAX .. ')')
    assert(colors_n >= 1, 'palette needs at least one color')
    local colors = {}
    for i = 1, colors_n do
        local hex = spec.colors[i]
        assert(is_valid_hex(hex), 'color #' .. i .. " must be '#rrggbb' hex")
        colors[i] = hex
    end
    assert(spec.map == nil or type(spec.map) == 'table', 'palette map must be from_hex -> to_hex')
    local map_in = spec.map or {}
    assert(
        not map_over_bound(map_in, M.PALETTE_COLORS_MAX),
        'too many recolor pairs (max ' .. M.PALETTE_COLORS_MAX .. ')'
    )
    local map = {}
    for from_hex, to_hex in pairs(map_in) do
        assert(is_valid_hex(from_hex) and is_valid_hex(to_hex), 'recolor pair keys and values must be hex')
        map[from_hex] = to_hex
    end
    local palette = { colors = colors, map = map }
    ch.palettes[name] = palette
    return palette
end

---Add an empty timeline. Keyframes arrive later via set_keyframe().
---Names are unique per character.
---@param ch Character
---@param name string animation name
---@param spec TimelineSpec
---@return Timeline timeline
function M.add_timeline(ch, name, spec)
    assert_is_character(ch)
    assert(is_valid_name(name), 'timeline name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    assert(type(spec) == 'table', 'timeline spec table required')
    assert(ch.timelines[name] == nil, "duplicate timeline name '" .. tostring(name) .. "'")
    assert(not map_over_bound(ch.timelines, M.TIMELINES_MAX), 'too many timelines (max ' .. M.TIMELINES_MAX .. ')')
    local loop = spec.loop
    assert(loop == true or loop == false or loop == 'pingpong', "loop must be true, false, or 'pingpong'")
    local fps = spec.fps
    assert(is_finite_number(fps) and fps > 0 and fps <= M.FPS_MAX, 'fps must be in (0, ' .. M.FPS_MAX .. ']')
    local duration = spec.duration_sec
    assert(
        is_finite_number(duration) and duration > 0 and duration <= M.DURATION_SEC_MAX,
        'duration_sec must be in (0, ' .. M.DURATION_SEC_MAX .. ']'
    )
    local tl = { loop = loop, fps = fps, duration_sec = duration, tracks = {} }
    ch.timelines[name] = tl
    return tl
end

---Add a 2D joint. Parents must already exist (add root joints first),
---which keeps builder-made skeletons acyclic by construction. The
---first joint added becomes skeleton.root; override by assigning
---ch.skeleton.root afterwards.
---@param ch Character
---@param spec JointSpec
---@return Joint joint
function M.add_joint(ch, spec)
    assert_is_character(ch)
    assert(type(spec) == 'table', 'joint spec table required')
    local name = spec.name
    assert(is_valid_name(name), 'joint name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    local joints = ch.skeleton.joints
    assert(joints[name] == nil, "duplicate joint name '" .. tostring(name) .. "'")
    assert(not map_over_bound(joints, M.JOINTS_MAX), 'too many joints (max ' .. M.JOINTS_MAX .. ')')
    local parent = spec.parent
    assert(parent == nil or is_valid_name(parent), 'joint parent must be nil or a joint name')
    if parent ~= nil then
        assert(joints[parent] ~= nil, "unknown parent joint '" .. parent .. "' (add parents first)")
    end
    local pivot_err = check_vec2(spec.pivot, -M.COORD_PX_MAX, M.COORD_PX_MAX, 'joint pivot')
    assert(pivot_err == nil, pivot_err or 'bad joint pivot')
    local rot_min, rot_max = spec.rot_min_deg, spec.rot_max_deg
    local rot_bound = M.ROT_DEG_ABS_MAX
    assert(is_finite_number(rot_min) and rot_min >= -rot_bound and rot_min <= rot_bound, 'rot_min_deg out of range')
    assert(is_finite_number(rot_max) and rot_max >= -rot_bound and rot_max <= rot_bound, 'rot_max_deg out of range')
    assert(rot_min <= rot_max, 'rot_min_deg must not exceed rot_max_deg')
    local length = spec.length_px
    assert(
        is_finite_number(length) and length >= 0 and length <= M.COORD_PX_MAX,
        'length_px must be in [0, ' .. M.COORD_PX_MAX .. ']'
    )
    local joint = {
        parent = parent,
        pivot = copy_vec2(spec.pivot),
        rot_min_deg = rot_min,
        rot_max_deg = rot_max,
        length_px = length,
    }
    joints[name] = joint
    if ch.skeleton.root == '' then
        ch.skeleton.root = name
    end
    return joint
end

---Add a 3D joint (data only: axis limits, no engine semantics).
---Same parent-first rule as add_joint.
---@param ch Character
---@param spec Joint3DSpec
---@return Joint3D joint
function M.add_joint_3d(ch, spec)
    assert_is_character(ch)
    assert(type(spec) == 'table', '3d joint spec table required')
    local name = spec.name
    assert(is_valid_name(name), '3d joint name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    local joints = ch.joints_3d
    if joints == nil then
        joints = {}
        ch.joints_3d = joints
    end
    assert(joints[name] == nil, "duplicate 3d joint name '" .. tostring(name) .. "'")
    assert(not map_over_bound(joints, M.JOINTS_3D_MAX), 'too many 3d joints (max ' .. M.JOINTS_3D_MAX .. ')')
    local parent = spec.parent
    assert(parent == nil or is_valid_name(parent), '3d joint parent must be nil or a joint name')
    if parent ~= nil then
        assert(joints[parent] ~= nil, "unknown parent 3d joint '" .. parent .. "' (add parents first)")
    end
    local joint = { parent = parent, limits = check_axis_limits(spec.limits) }
    joints[name] = joint
    return joint
end

---Append a keyframe to a timeline's part track. Keyframes must arrive
---in non-decreasing time order (the sampler assumes sorted tracks).
---The keyframe is copied; the caller's table never aliases the track.
---@param ch Character
---@param anim string timeline name
---@param part string part name (must be declared)
---@param kf Keyframe
---@return Keyframe stored copy
function M.set_keyframe(ch, anim, part, kf)
    assert_is_character(ch)
    assert(is_valid_name(anim), 'animation name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    assert(is_valid_name(part), 'part name must be 1..' .. M.NAME_LEN_MAX .. ' chars')
    local tl = ch.timelines[anim]
    assert(tl ~= nil, "unknown timeline '" .. tostring(anim) .. "'")
    assert(part_by_name(ch, part) ~= nil, "unknown part '" .. tostring(part) .. "'")
    assert(type(kf) == 'table', 'keyframe table required')
    local t = kf.t
    assert(is_finite_number(t) and t >= 0, 'keyframe t must be a finite number >= 0')
    local track = tl.tracks[part]
    if track == nil then
        track = {}
        tl.tracks[part] = track
    end
    assert(#track < M.KEYFRAMES_MAX, 'too many keyframes (max ' .. M.KEYFRAMES_MAX .. ')')
    local last = track[#track]
    if last ~= nil then
        assert(t >= last.t, 'keyframes must be appended in non-decreasing time order')
    end
    check_keyframe_fields(kf)
    local stored = copy_keyframe(kf)
    track[#track + 1] = stored
    return stored
end

-- ============ validation (pure, never raises) ============

---@param t table
---@param allowed table<string, boolean>
---@param what string
---@param errors string[]
---@param prefix string
local function check_unknown_fields(t, allowed, what, errors, prefix)
    for k in pairs(t) do
        if allowed[k] ~= true then
            errors[#errors + 1] = prefix .. what .. " has unexpected field '" .. tostring(k) .. "'"
        end
    end
end

---@param tags unknown
---@param what string
---@param errors string[]
---@param prefix string
local function validate_tags(tags, what, errors, prefix)
    if tags == nil then
        return
    end
    if type(tags) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ': tags must be an array'
        return
    end
    local n, over = array_len_bounded(tags, M.TAGS_MAX)
    if over then
        errors[#errors + 1] = prefix .. what .. ': too many tags (max ' .. M.TAGS_MAX .. ')'
        return
    end
    for i = 1, n do
        if not is_valid_name(tags[i]) then
            errors[#errors + 1] = prefix .. what .. ': bad tag #' .. i
        end
    end
end

---@param parts unknown
---@param errors string[]
---@return string[] names of well-formed parts
local function validate_parts(parts, errors)
    local names = {}
    local prefix = 'parts: '
    if type(parts) ~= 'table' then
        errors[#errors + 1] = prefix .. 'must be an array'
        return names
    end
    local n, over = array_len_bounded(parts, M.PARTS_MAX)
    if over then
        errors[#errors + 1] = prefix .. 'too many (max ' .. M.PARTS_MAX .. ')'
        return names
    end
    local seen = {}
    for i = 1, n do
        local p = parts[i]
        local what = 'part #' .. i
        if type(p) ~= 'table' then
            errors[#errors + 1] = prefix .. what .. ' must be a table'
        else
            check_unknown_fields(
                p,
                { name = true, anchor = true, zindex = true, sprite = true, tags = true },
                what,
                errors,
                prefix
            )
            local name = p.name
            if not is_valid_name(name) then
                errors[#errors + 1] = prefix .. what .. ': bad name'
            elseif seen[name] then
                errors[#errors + 1] = prefix .. "duplicate name '" .. name .. "'"
            else
                seen[name] = true
                names[#names + 1] = name
            end
            local aerr = check_vec2(p.anchor, -M.COORD_PX_MAX, M.COORD_PX_MAX, 'anchor')
            if aerr then
                errors[#errors + 1] = prefix .. what .. ': ' .. aerr
            end
            if not is_integer_valued(p.zindex) or p.zindex < M.ZINDEX_MIN or p.zindex > M.ZINDEX_MAX then
                errors[#errors + 1] = prefix .. what .. ': zindex out of range'
            end
            if
                p.sprite ~= nil
                and (type(p.sprite) ~= 'string' or #p.sprite < 1 or #p.sprite > M.SPRITE_PATH_LEN_MAX)
            then
                errors[#errors + 1] = prefix .. what .. ': bad sprite path'
            end
            validate_tags(p.tags, what, errors, prefix)
        end
    end
    return names
end

---@param colors unknown
---@param what string
---@param errors string[]
---@param prefix string
local function validate_palette_colors(colors, what, errors, prefix)
    if type(colors) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ': colors must be an array'
        return
    end
    local n, over = array_len_bounded(colors, M.PALETTE_COLORS_MAX)
    if over then
        errors[#errors + 1] = prefix .. what .. ': too many colors (max ' .. M.PALETTE_COLORS_MAX .. ')'
        return
    end
    if n < 1 then
        errors[#errors + 1] = prefix .. what .. ': needs at least one color'
    end
    for i = 1, n do
        if not is_valid_hex(colors[i]) then
            errors[#errors + 1] = prefix .. what .. ': color #' .. i .. " must be '#rrggbb' hex"
        end
    end
end

---@param map unknown
---@param what string
---@param errors string[]
---@param prefix string
local function validate_palette_map(map, what, errors, prefix)
    if map == nil then
        return
    end
    if type(map) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ': map must be from_hex -> to_hex'
        return
    end
    if map_over_bound(map, M.PALETTE_COLORS_MAX) then
        errors[#errors + 1] = prefix .. what .. ': too many recolor pairs'
        return
    end
    for from_hex, to_hex in pairs(map) do
        if not is_valid_hex(from_hex) or not is_valid_hex(to_hex) then
            errors[#errors + 1] = prefix .. what .. ': recolor pairs must be hex -> hex'
        end
    end
end

---@param palettes unknown
---@param errors string[]
local function validate_palettes(palettes, errors)
    local prefix = 'palettes: '
    if type(palettes) ~= 'table' then
        errors[#errors + 1] = prefix .. 'must be a map'
        return
    end
    if map_over_bound(palettes, M.PALETTES_MAX) then
        errors[#errors + 1] = prefix .. 'too many (max ' .. M.PALETTES_MAX .. ')'
        return
    end
    for k in pairs(palettes) do
        if type(k) ~= 'string' or not is_valid_name(k) then
            errors[#errors + 1] = prefix .. 'bad palette name'
        end
    end
    for _, name in ipairs(sorted_keys(palettes)) do
        local what = "palette '" .. name .. "'"
        local p = palettes[name]
        if type(p) ~= 'table' then
            errors[#errors + 1] = prefix .. what .. ' must be a table'
        else
            check_unknown_fields(p, { colors = true, map = true }, what, errors, prefix)
            validate_palette_colors(p.colors, what, errors, prefix)
            validate_palette_map(p.map, what, errors, prefix)
        end
    end
end

---@param kf unknown
---@param what string
---@param last_t number|nil previous keyframe time, or nil
---@param errors string[]
---@param prefix string
---@return number|nil new_last_t nil when kf is not a usable keyframe
local function validate_keyframe(kf, what, last_t, errors, prefix)
    if type(kf) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ': must be a table'
        return nil
    end
    check_unknown_fields(
        kf,
        { t = true, pos = true, rot_deg = true, scale = true, visible = true },
        what,
        errors,
        prefix
    )
    local t = kf.t
    if not is_finite_number(t) or t < 0 then
        errors[#errors + 1] = prefix .. what .. ': t must be a finite number >= 0'
        return nil
    end
    if last_t ~= nil and t < last_t then
        errors[#errors + 1] = prefix .. what .. ': keyframes out of order'
    end
    if kf.pos ~= nil then
        local err = check_vec2(kf.pos, -M.COORD_PX_MAX, M.COORD_PX_MAX, 'pos')
        if err then
            errors[#errors + 1] = prefix .. what .. ': ' .. err
        end
    end
    if kf.scale ~= nil then
        local err = check_scale_vec2(kf.scale, 'scale')
        if err then
            errors[#errors + 1] = prefix .. what .. ': ' .. err
        end
    end
    if
        kf.rot_deg ~= nil
        and (not is_finite_number(kf.rot_deg) or kf.rot_deg < -M.ROT_DEG_ABS_MAX or kf.rot_deg > M.ROT_DEG_ABS_MAX)
    then
        errors[#errors + 1] = prefix .. what .. ': rot_deg out of range'
    end
    if kf.visible ~= nil and type(kf.visible) ~= 'boolean' then
        errors[#errors + 1] = prefix .. what .. ': visible must be boolean'
    end
    return t
end

---@param part_name string
---@param track unknown
---@param tl_what string
---@param errors string[]
local function validate_track(part_name, track, tl_what, errors)
    local prefix = 'timelines: '
    local what = tl_what .. " track '" .. part_name .. "'"
    if type(track) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ' must be an array'
        return
    end
    local n, over = array_len_bounded(track, M.KEYFRAMES_MAX)
    if over then
        errors[#errors + 1] = prefix .. what .. ' too many keyframes (max ' .. M.KEYFRAMES_MAX .. ')'
        return
    end
    local last_t = nil
    for i = 1, n do
        last_t = validate_keyframe(track[i], what .. ' kf #' .. i, last_t, errors, prefix)
    end
end

---@param name string
---@param tl unknown
---@param known_parts table<string, boolean>
---@param errors string[]
local function validate_timeline(name, tl, known_parts, errors)
    local prefix = 'timelines: '
    local what = "timeline '" .. name .. "'"
    if not is_valid_name(name) then
        errors[#errors + 1] = prefix .. 'bad timeline name'
    end
    if type(tl) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ' must be a table'
        return
    end
    check_unknown_fields(tl, { loop = true, fps = true, duration_sec = true, tracks = true }, what, errors, prefix)
    local loop = tl.loop
    if loop ~= true and loop ~= false and loop ~= 'pingpong' then
        errors[#errors + 1] = prefix .. what .. ": loop must be true, false, or 'pingpong'"
    end
    if not is_finite_number(tl.fps) or tl.fps <= 0 or tl.fps > M.FPS_MAX then
        errors[#errors + 1] = prefix .. what .. ': fps out of range'
    end
    if not is_finite_number(tl.duration_sec) or tl.duration_sec <= 0 or tl.duration_sec > M.DURATION_SEC_MAX then
        errors[#errors + 1] = prefix .. what .. ': duration_sec out of range'
    end
    local tracks = tl.tracks
    if tracks == nil then
        return
    end
    if type(tracks) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ': tracks must be a map'
        return
    end
    for k in pairs(tracks) do
        if type(k) ~= 'string' then
            errors[#errors + 1] = prefix .. what .. ': track key must be a part name'
        end
    end
    for _, part_name in ipairs(sorted_keys(tracks)) do
        if known_parts[part_name] ~= true then
            errors[#errors + 1] = prefix .. what .. ": track references undeclared part '" .. part_name .. "'"
        else
            validate_track(part_name, tracks[part_name], what, errors)
        end
    end
end

---@param timelines unknown
---@param part_names string[]
---@param errors string[]
local function validate_timelines(timelines, part_names, errors)
    local prefix = 'timelines: '
    if type(timelines) ~= 'table' then
        errors[#errors + 1] = prefix .. 'must be a map'
        return
    end
    if map_over_bound(timelines, M.TIMELINES_MAX) then
        errors[#errors + 1] = prefix .. 'too many (max ' .. M.TIMELINES_MAX .. ')'
        return
    end
    local known = {}
    for _, n in ipairs(part_names) do
        known[n] = true
    end
    for _, name in ipairs(sorted_keys(timelines)) do
        validate_timeline(name, timelines[name], known, errors)
    end
end

---@param name string
---@param j unknown
---@param joints table<string, any>
---@param errors string[]
local function validate_joint(name, j, joints, errors)
    local prefix = 'skeleton: '
    local what = "joint '" .. name .. "'"
    if type(j) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ' must be a table'
        return
    end
    check_unknown_fields(
        j,
        { parent = true, pivot = true, rot_min_deg = true, rot_max_deg = true, length_px = true },
        what,
        errors,
        prefix
    )
    local parent = j.parent
    if parent ~= nil then
        if not is_valid_name(parent) then
            errors[#errors + 1] = prefix .. what .. ': parent must be nil or a joint name'
        elseif joints[parent] == nil then
            errors[#errors + 1] = prefix .. what .. ": unknown parent '" .. parent .. "'"
        end
    end
    local perr = check_vec2(j.pivot, -M.COORD_PX_MAX, M.COORD_PX_MAX, 'pivot')
    if perr then
        errors[#errors + 1] = prefix .. what .. ': ' .. perr
    end
    local rmin, rmax = j.rot_min_deg, j.rot_max_deg
    local bound = M.ROT_DEG_ABS_MAX
    if not is_finite_number(rmin) or rmin < -bound or rmin > bound then
        errors[#errors + 1] = prefix .. what .. ': rot_min_deg out of range'
    end
    if not is_finite_number(rmax) or rmax < -bound or rmax > bound then
        errors[#errors + 1] = prefix .. what .. ': rot_max_deg out of range'
    end
    if is_finite_number(rmin) and is_finite_number(rmax) and rmin > rmax then
        errors[#errors + 1] = prefix .. what .. ': rot_min_deg exceeds rot_max_deg'
    end
    if not is_finite_number(j.length_px) or j.length_px < 0 or j.length_px > M.COORD_PX_MAX then
        errors[#errors + 1] = prefix .. what .. ': length_px out of range'
    end
end

---@param skeleton unknown
---@param errors string[]
local function validate_skeleton(skeleton, errors)
    local prefix = 'skeleton: '
    if type(skeleton) ~= 'table' then
        errors[#errors + 1] = prefix .. 'must be a table'
        return
    end
    check_unknown_fields(skeleton, { joints = true, root = true }, 'skeleton', errors, prefix)
    local joints = skeleton.joints
    if type(joints) ~= 'table' then
        errors[#errors + 1] = prefix .. 'joints must be a map'
        return
    end
    if map_over_bound(joints, M.JOINTS_MAX) then
        errors[#errors + 1] = prefix .. 'too many joints (max ' .. M.JOINTS_MAX .. ')'
        return
    end
    for k in pairs(joints) do
        if type(k) ~= 'string' or not is_valid_name(k) then
            errors[#errors + 1] = prefix .. 'bad joint name'
        end
    end
    for _, name in ipairs(sorted_keys(joints)) do
        validate_joint(name, joints[name], joints, errors)
    end
    local root = skeleton.root
    if next(joints) == nil then
        if root ~= '' and root ~= nil then
            errors[#errors + 1] = prefix .. 'root must be unset when no joints exist'
        end
    elseif not is_valid_name(root) or joints[root] == nil then
        errors[#errors + 1] = prefix .. "root must name an existing joint, got '" .. tostring(root) .. "'"
    end
    local cyc = find_joint_cycle(joints, M.JOINTS_MAX)
    if cyc then
        errors[#errors + 1] = prefix .. "parent cycle detected at joint '" .. cyc .. "'"
    end
end

---@param limits unknown
---@param what string
---@param errors string[]
---@param prefix string
local function validate_axis_limits(limits, what, errors, prefix)
    if type(limits) ~= 'table' then
        errors[#errors + 1] = prefix .. what .. ': limits must be a table'
        return
    end
    check_unknown_fields(limits, { pitch = true, yaw = true, roll = true }, what .. '.limits', errors, prefix)
    for _, axis in ipairs({ 'pitch', 'yaw', 'roll' }) do
        local pair = limits[axis]
        local awhat = what .. '.limits.' .. axis
        if type(pair) ~= 'table' then
            errors[#errors + 1] = prefix .. awhat .. ' must be a {min, max} pair'
        else
            if pair[3] ~= nil then
                errors[#errors + 1] = prefix .. awhat .. ' must have exactly 2 entries'
            end
            local lo, hi = pair[1], pair[2]
            local bound = M.JOINT3D_DEG_ABS_MAX
            if not is_finite_number(lo) or lo < -bound or lo > bound then
                errors[#errors + 1] = prefix .. awhat .. '[1] out of range'
            end
            if not is_finite_number(hi) or hi < -bound or hi > bound then
                errors[#errors + 1] = prefix .. awhat .. '[2] out of range'
            end
            if is_finite_number(lo) and is_finite_number(hi) and lo > hi then
                errors[#errors + 1] = prefix .. awhat .. ': min exceeds max'
            end
        end
    end
end

---@param j3d unknown
---@param errors string[]
local function validate_joints_3d(j3d, errors)
    local prefix = 'joints_3d: '
    if j3d == nil then
        return
    end
    if type(j3d) ~= 'table' then
        errors[#errors + 1] = prefix .. 'must be a map or nil'
        return
    end
    if map_over_bound(j3d, M.JOINTS_3D_MAX) then
        errors[#errors + 1] = prefix .. 'too many (max ' .. M.JOINTS_3D_MAX .. ')'
        return
    end
    for _, name in ipairs(sorted_keys(j3d)) do
        local what = "joint '" .. name .. "'"
        local j = j3d[name]
        if type(j) ~= 'table' then
            errors[#errors + 1] = prefix .. what .. ' must be a table'
        else
            check_unknown_fields(j, { parent = true, limits = true }, what, errors, prefix)
            local parent = j.parent
            if parent ~= nil then
                if not is_valid_name(parent) then
                    errors[#errors + 1] = prefix .. what .. ': bad parent name'
                elseif j3d[parent] == nil then
                    errors[#errors + 1] = prefix .. what .. ": unknown parent '" .. parent .. "'"
                end
            end
            validate_axis_limits(j.limits, what, errors, prefix)
        end
    end
    local cyc = find_joint_cycle(j3d, M.JOINTS_3D_MAX)
    if cyc then
        errors[#errors + 1] = prefix .. "parent cycle detected at joint '" .. cyc .. "'"
    end
end

---Validate a character definition. Pure: no side effects, never raises,
---safe on hostile shapes. Returns ok plus a list of human-readable
---errors (empty when ok).
---@param ch table
---@return boolean ok
---@return string[] errors
function M.validate_character(ch)
    local errors = {}
    if type(ch) ~= 'table' then
        return false, { 'character must be a table' }
    end
    if ch.version ~= M.VERSION then
        errors[#errors + 1] = 'unsupported version: ' .. tostring(ch.version)
    end
    if not is_valid_name(ch.name) then
        errors[#errors + 1] = 'character name must be 1..' .. M.NAME_LEN_MAX .. ' chars'
    end
    local part_names = validate_parts(ch.parts, errors)
    validate_palettes(ch.palettes, errors)
    validate_timelines(ch.timelines, part_names, errors)
    validate_skeleton(ch.skeleton, errors)
    validate_joints_3d(ch.joints_3d, errors)
    return #errors == 0, errors
end

-- ============ serialization ============

---@param p CharacterPart
---@return CharacterPart
local function copy_part(p)
    return {
        name = p.name,
        anchor = copy_vec2(p.anchor),
        zindex = p.zindex,
        sprite = p.sprite,
        tags = copy_string_array(p.tags),
    }
end

---@param p CharacterPalette
---@return CharacterPalette
local function copy_palette(p)
    local map = {}
    for k, v in pairs(p.map) do
        map[k] = v
    end
    return { colors = copy_string_array(p.colors), map = map }
end

---@param tl Timeline
---@return Timeline
local function copy_timeline(tl)
    local tracks = {}
    for _, part_name in ipairs(sorted_keys(tl.tracks)) do
        local src = tl.tracks[part_name]
        local track = {}
        for i = 1, #src do
            track[i] = copy_keyframe(src[i])
        end
        tracks[part_name] = track
    end
    return { loop = tl.loop, fps = tl.fps, duration_sec = tl.duration_sec, tracks = tracks }
end

---@param j Joint
---@return Joint
local function copy_joint(j)
    return {
        parent = j.parent,
        pivot = copy_vec2(j.pivot),
        rot_min_deg = j.rot_min_deg,
        rot_max_deg = j.rot_max_deg,
        length_px = j.length_px,
    }
end

---@param j Joint3D
---@return Joint3D
local function copy_joint_3d(j)
    return {
        parent = j.parent,
        limits = {
            pitch = { j.limits.pitch[1], j.limits.pitch[2] },
            yaw = { j.limits.yaw[1], j.limits.yaw[2] },
            roll = { j.limits.roll[1], j.limits.roll[2] },
        },
    }
end

---Serialize a character to a plain table. Deep-copies everything, so
---mutating the result never aliases the character. Map keys are
---inserted in sorted order as a best-effort toward stable output.
---@param ch Character
---@return table snapshot
function M.to_table(ch)
    assert_is_character(ch)
    local out = {
        name = ch.name,
        version = M.VERSION,
        parts = {},
        palettes = {},
        timelines = {},
        skeleton = { joints = {}, root = ch.skeleton.root },
    }
    for i = 1, #ch.parts do
        out.parts[i] = copy_part(ch.parts[i])
    end
    for _, name in ipairs(sorted_keys(ch.palettes)) do
        out.palettes[name] = copy_palette(ch.palettes[name])
    end
    for _, name in ipairs(sorted_keys(ch.timelines)) do
        out.timelines[name] = copy_timeline(ch.timelines[name])
    end
    for _, name in ipairs(sorted_keys(ch.skeleton.joints)) do
        out.skeleton.joints[name] = copy_joint(ch.skeleton.joints[name])
    end
    if ch.joints_3d ~= nil then
        out.joints_3d = {}
        for _, name in ipairs(sorted_keys(ch.joints_3d)) do
            out.joints_3d[name] = copy_joint_3d(ch.joints_3d[name])
        end
    end
    return out
end

---Insert joints parent-first so the builder's parent-exists contract
---holds regardless of map order. Bounded: each pass places at least one
---joint, and validate_character() already ruled out cycles, so this
---always terminates with ok == true on validated input.
---@param ch Character
---@param joints table<string, any>
---@param has fun(name: string): boolean true when name is already placed
---@param adder fun(ch: Character, name: string, j: table)
---@return boolean ok
local function insert_joints_topo(ch, joints, has, adder)
    local pending = sorted_keys(joints)
    for _ = 1, #pending + 1 do
        if #pending == 0 then
            return true
        end
        local progressed = false
        local rest = {}
        for _, name in ipairs(pending) do
            local parent = joints[name].parent
            if parent == nil or has(parent) then
                adder(ch, name, joints[name])
                progressed = true
            else
                rest[#rest + 1] = name
            end
        end
        if not progressed then
            return false
        end
        pending = rest
    end
    return #pending == 0
end

---Rebuild a character from a plain table. Validates first: returns
---nil plus an error on unknown versions or malformed shapes, and never
---aliases the input table. Round-trip guarantee:
---from_table(to_table(ch)) deep-equals ch.
---@param t table
---@return Character|nil ch
---@return string|nil err
function M.from_table(t)
    if type(t) ~= 'table' then
        return nil, 'character table required'
    end
    local ok, verrs = M.validate_character(t)
    if not ok then
        return nil, verrs[1] or 'invalid character definition'
    end
    local ch = M.new_character(t.name)
    for i = 1, #t.parts do
        M.add_part(ch, t.parts[i])
    end
    for _, name in ipairs(sorted_keys(t.palettes)) do
        local p = t.palettes[name]
        M.add_palette(ch, { name = name, colors = p.colors, map = p.map })
    end
    for _, name in ipairs(sorted_keys(t.timelines)) do
        local src = t.timelines[name]
        M.add_timeline(ch, name, { loop = src.loop, fps = src.fps, duration_sec = src.duration_sec })
        for _, part_name in ipairs(sorted_keys(src.tracks)) do
            local track = src.tracks[part_name]
            for i = 1, #track do
                M.set_keyframe(ch, name, part_name, track[i])
            end
        end
    end
    local joints_ok = insert_joints_topo(ch, t.skeleton.joints, function(n)
        return ch.skeleton.joints[n] ~= nil
    end, function(c, n, j)
        M.add_joint(c, {
            name = n,
            parent = j.parent,
            pivot = j.pivot,
            rot_min_deg = j.rot_min_deg,
            rot_max_deg = j.rot_max_deg,
            length_px = j.length_px,
        })
    end)
    if not joints_ok then
        return nil, 'skeleton: joint parent cycle'
    end
    -- The builder auto-roots the first joint added; restore the
    -- serialized root, which validate confirmed names a real joint.
    ch.skeleton.root = t.skeleton.root
    if t.joints_3d ~= nil then
        local ok3 = insert_joints_topo(ch, t.joints_3d, function(n)
            return ch.joints_3d ~= nil and ch.joints_3d[n] ~= nil
        end, function(c, n, j)
            M.add_joint_3d(c, { name = n, parent = j.parent, limits = j.limits })
        end)
        if not ok3 then
            return nil, 'joints_3d: joint parent cycle'
        end
    end
    return ch
end

-- ============ pose sampling ============

---@param kf Keyframe
---@return SampledPart resolved with defaults for missing fields
local function resolve_keyframe(kf)
    local pos = { x = 0, y = 0 }
    if kf.pos ~= nil then
        pos = copy_vec2(kf.pos)
    end
    local scale = { x = 1, y = 1 }
    if kf.scale ~= nil then
        scale = copy_vec2(kf.scale)
    end
    local visible = true
    if kf.visible ~= nil then
        visible = kf.visible
    end
    return { pos = pos, rot_deg = kf.rot_deg or 0, scale = scale, visible = visible }
end

---@param a number
---@param b number
---@param f number fraction in [0, 1]
---@return number
local function lerp(a, b, f)
    return a + (b - a) * f
end

---@param k1 Keyframe earlier keyframe
---@param k2 Keyframe later keyframe
---@param f number fraction in [0, 1)
---@return SampledPart numbers blended; visible snaps from k1
local function blend_keyframes(k1, k2, f)
    local p1, p2 = resolve_keyframe(k1), resolve_keyframe(k2)
    return {
        pos = { x = lerp(p1.pos.x, p2.pos.x, f), y = lerp(p1.pos.y, p2.pos.y, f) },
        rot_deg = lerp(p1.rot_deg, p2.rot_deg, f),
        scale = { x = lerp(p1.scale.x, p2.scale.x, f), y = lerp(p1.scale.y, p2.scale.y, f) },
        visible = p1.visible,
    }
end

---Sample one part track at time t. Empty/missing tracks yield the
---default pose (pos {0,0}, rot 0, scale {1,1}, visible true). Before
---the first keyframe the first pose holds; after the last, the last.
---@param track Keyframe[]|nil
---@param t number effective time within the timeline
---@return SampledPart
local function sample_track(track, t)
    if track == nil or #track == 0 then
        return resolve_keyframe({ t = 0 })
    end
    local k1 = track[1]
    local k2 = nil
    for i = 1, #track do
        if track[i].t <= t then
            k1 = track[i]
            k2 = track[i + 1]
        else
            break
        end
    end
    if k2 == nil then
        return resolve_keyframe(k1)
    end
    -- k1 is the last keyframe at or before t, so k1.t <= t < k2.t and
    -- the divisor below is strictly positive.
    local f = (t - k1.t) / (k2.t - k1.t)
    return blend_keyframes(k1, k2, f)
end

---Sample a pose: { part_name -> { pos, rot_deg, scale, visible } }.
---Linear interpolation between keyframes; loop=true wraps t,
---'pingpong' mirrors it, false clamps to [0, duration]. Negative t
---clamps to 0. Parts with no track get the default pose. This is the
---engine-agnostic surface per-engine modules consume.
---@param ch table character definition
---@param anim_name string timeline name
---@param t_sec number time in seconds
---@return table<string, SampledPart>|nil pose
---@return string|nil err
function M.sample_pose(ch, anim_name, t_sec)
    if type(ch) ~= 'table' then
        return nil, 'character table required'
    end
    if type(anim_name) ~= 'string' or anim_name == '' then
        return nil, 'animation name required'
    end
    local timelines = ch.timelines
    if type(timelines) ~= 'table' then
        return nil, 'character has no timelines'
    end
    local tl = timelines[anim_name]
    if type(tl) ~= 'table' then
        return nil, "unknown timeline '" .. anim_name .. "'"
    end
    if not is_finite_number(t_sec) then
        return nil, 't_sec must be a finite number'
    end
    local duration = tl.duration_sec
    if not is_finite_number(duration) or duration <= 0 then
        return nil, 'timeline has an invalid duration'
    end
    local t = t_sec
    if t < 0 then
        t = 0
    end
    local t_eff
    if tl.loop == 'pingpong' then
        local period = duration * 2
        local m = t % period
        if m > duration then
            t_eff = period - m
        else
            t_eff = m
        end
    elseif tl.loop == true then
        t_eff = t % duration
    else
        t_eff = math.min(t, duration)
    end
    local tracks = tl.tracks
    if type(tracks) ~= 'table' then
        return nil, 'timeline has no tracks table'
    end
    local pose = {}
    local parts = ch.parts
    if type(parts) == 'table' then
        for i = 1, #parts do
            local part = parts[i]
            if type(part) == 'table' and type(part.name) == 'string' then
                pose[part.name] = sample_track(tracks[part.name], t_eff)
            end
        end
    end
    return pose
end

return M
