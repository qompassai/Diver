-- #################################################################
-- /qompassai/Diver/lua/games/love2d/character.lua
-- Qompass AI LÖVE Character Builder
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
-- Build a runnable LÖVE 11.5 project skeleton from a validated
-- shared-character definition: conf.lua + main.lua (a timeline player
-- driven by poses baked with shared.character.sample_pose) + data.lua
-- (parts and baked frames). Part sprites load from a directory at
-- runtime via love.graphics.newImage.
--
-- Pure: no vim.* at require time, no engine binary needed. Runs under
-- Lua 5.4, LuaJIT, and inside Neovim.
--
-- 2D only. There is NO true 3D in LÖVE -- pseudo-3D (billboards, the
-- g3d library) is out of scope for this module; capabilities() reports
-- dims_3d = false with the reason.
local kit = require('games.shared.character')

local M = {}

M.FRAMES_MAX = 4096
M.PROJECT_NAME_LEN_MAX = 48
M.WINDOW_DIM_MAX = 4096
M.SERIALIZE_DEPTH_MAX = 16

---@class Love2dCharacterOpts
---@field name? string project name override (sanitized)
---@field width? integer window width (default 800)
---@field height? integer window height (default 600)
---@field sprite_dir? string runtime sprite directory (default 'assets')

---@class Love2dProjectFile
---@field path string relative path inside the project
---@field content string file text

---@class Love2dProject
---@field project_name string sanitized project name
---@field files Love2dProjectFile[] conf.lua, main.lua, data.lua
---@field anims string[] animation names baked, sorted

---Keep only word chars, dash and underscore; collapse the rest to '_'.
---Guarantees the result is a safe single path segment, never empty.
---@param name string
---@return string safe
local function sanitize_name(name)
    local safe = tostring(name):gsub('[%c%z]', ''):gsub('[^%w%-_]', '_')
    safe = safe:sub(1, M.PROJECT_NAME_LEN_MAX)
    if safe == '' then
        return 'character'
    end
    return safe
end

---Escape a string for single-quoted Lua embedding. Rejects NUL.
---@param s string
---@return string|nil escaped
local function lua_quote(s)
    if type(s) ~= 'string' or s:find('%z') ~= nil then
        return nil
    end
    return "'" .. s:gsub('\\', '\\\\'):gsub("'", "\\'"):gsub('\n', '\\n'):gsub('\r', '\\r') .. "'"
end

---Reject sprite paths that escape the sprite directory: absolute
---paths and '..' segments are hostile. Returns nil, err on rejection.
---@param sprite string|nil
---@return string|nil safe
---@return string|nil err
local function check_sprite_path(sprite)
    if sprite == nil then
        return nil, nil
    end
    if type(sprite) ~= 'string' or sprite == '' then
        return nil, 'love2d: sprite path must be a non-empty string'
    end
    if sprite:sub(1, 1) == '/' or sprite:find('%.%.') ~= nil or sprite:find('%z') ~= nil then
        return nil, "love2d: unsafe sprite path '" .. sprite .. "'"
    end
    return sprite, nil
end

---@param v number
---@return string
local function num_str(v)
    if v == math.floor(v) and math.abs(v) < 1e15 then
        return string.format('%d', v)
    end
    return string.format('%.6f', v)
end

---@param v any
---@param depth integer
---@return string|nil chunk
local function encode_value(v, depth)
    if depth > M.SERIALIZE_DEPTH_MAX then
        return nil
    end
    local tv = type(v)
    if tv == 'number' then
        return num_str(v)
    end
    if tv == 'string' then
        return lua_quote(v)
    end
    if tv == 'boolean' then
        return v and 'true' or 'false'
    end
    if tv ~= 'table' then
        return nil
    end
    local is_seq = true
    local n = #v
    for k in pairs(v) do
        if type(k) ~= 'number' or k < 1 or k > n or k ~= math.floor(k) then
            is_seq = false
            break
        end
    end
    local parts = {}
    if is_seq then
        for i = 1, n do
            local item = encode_value(v[i], depth + 1)
            if item == nil then
                return nil
            end
            parts[#parts + 1] = item
        end
        return '{ ' .. table.concat(parts, ', ') .. ' }'
    end
    local keys = {}
    for k in pairs(v) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for _, k in ipairs(keys) do
        if type(k) ~= 'string' or k:find('^[%a_][%w_]*$') == nil then
            return nil
        end
        local item = encode_value(v[k], depth + 1)
        if item == nil then
            return nil
        end
        parts[#parts + 1] = k .. ' = ' .. item
    end
    return '{ ' .. table.concat(parts, ', ') .. ' }'
end

---@param ch table validated character
---@param anim_name string
---@param fps number
---@return table[]|nil frames {t, parts={name->{pos,rot_deg,scale,visible}}}
---@return string|nil err
local function bake_anim_frames(ch, anim_name, fps)
    local tl = ch.timelines[anim_name]
    local duration = tl.duration_sec
    local count = math.floor(duration * fps + 1e-9) + 1
    if count > M.FRAMES_MAX then
        return nil, 'love2d: animation frame count exceeds cap'
    end
    local frames = {}
    for i = 1, count do
        local t = math.min((i - 1) / fps, duration)
        local pose, perr = kit.sample_pose(ch, anim_name, t)
        if pose == nil then
            return nil, 'love2d: sample_pose failed: ' .. tostring(perr)
        end
        local baked_parts = {}
        for _, part in ipairs(ch.parts) do
            local s = pose[part.name]
            baked_parts[part.name] = {
                pos = { x = s.pos.x, y = s.pos.y },
                rot_deg = s.rot_deg,
                scale = { x = s.scale.x, y = s.scale.y },
                visible = s.visible,
            }
        end
        frames[i] = { t = t, parts = baked_parts }
    end
    return frames, nil
end

---Bake one timeline to frames via shared.character.sample_pose.
---Public so tests and other tooling can reuse the bake step.
---@param ch table character definition (validated first)
---@param anim_name string timeline name
---@param opts? { fps?: number }
---@return table[]|nil frames
---@return string|nil err
function M.bake_frames(ch, anim_name, opts)
    opts = opts or {}
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, 'love2d: invalid character: ' .. tostring(verr[1])
    end
    if type(anim_name) ~= 'string' or ch.timelines[anim_name] == nil then
        return nil, 'love2d: unknown animation ' .. tostring(anim_name)
    end
    local fps = opts.fps or ch.timelines[anim_name].fps
    if type(fps) ~= 'number' or fps <= 0 or fps > kit.FPS_MAX then
        return nil, 'love2d: fps out of range'
    end
    return bake_anim_frames(ch, anim_name, fps)
end

---@param ch table validated character
---@return table|nil data serializable data table
---@return string|nil err
local function build_data_table(ch)
    local anim_names = {}
    for name in pairs(ch.timelines) do
        anim_names[#anim_names + 1] = name
    end
    table.sort(anim_names)
    local parts = {}
    for _, part in ipairs(ch.parts) do
        local sprite, serr = check_sprite_path(part.sprite)
        if serr ~= nil then
            return nil, serr
        end
        parts[#parts + 1] = {
            name = part.name,
            anchor = { x = part.anchor.x, y = part.anchor.y },
            zindex = part.zindex,
            sprite = sprite,
        }
    end
    local anims = {}
    for _, name in ipairs(anim_names) do
        local frames, ferr = bake_anim_frames(ch, name, ch.timelines[name].fps)
        if frames == nil then
            return nil, ferr
        end
        anims[name] = { fps = ch.timelines[name].fps, loop = ch.timelines[name].loop, frames = frames }
    end
    return {
        name = ch.name,
        default_anim = anim_names[1],
        parts = parts,
        anims = anims,
    },
        nil
end

local MAIN_TEMPLATE = [==[
-- Generated by diver games/love2d/character.lua -- @@PROJECT@@.
-- 2D timeline player. Poses were baked at generation time with
-- shared.character.sample_pose(); part sprites load from @@SPRITE_DIR@@/.
-- Press an animation name (idle, walk, ...) to switch timelines.
local data = require('data')

local SPRITE_DIR = '@@SPRITE_DIR@@'

local images = {}
local draw_order = {}
local state = { anim = '@@DEFAULT_ANIM@@', clock = 0.0 }

function love.load()
    for _, part in ipairs(data.parts) do
        if part.sprite ~= nil then
            images[part.name] = love.graphics.newImage(SPRITE_DIR .. '/' .. part.sprite)
        end
        draw_order[#draw_order + 1] = part
    end
    table.sort(draw_order, function(a, b)
        return a.zindex < b.zindex
    end)
end

local function current_anim()
    return data.anims[state.anim] or data.anims[data.default_anim]
end

function love.update(dt)
    local anim = current_anim()
    if anim == nil or #anim.frames == 0 then
        return
    end
    -- Baked frames already encode loop/pingpong/clamp, so the clock
    -- always wraps over the baked duration.
    local duration = #anim.frames / anim.fps
    state.clock = (state.clock + dt) % duration
end

function love.draw()
    local anim = current_anim()
    if anim == nil or #anim.frames == 0 then
        return
    end
    local index = math.floor(state.clock * anim.fps) % #anim.frames + 1
    local pose = anim.frames[index].parts
    for _, part in ipairs(draw_order) do
        local sample = pose[part.name]
        local image = images[part.name]
        if sample ~= nil and sample.visible and image ~= nil then
            love.graphics.draw(
                image,
                sample.pos.x,
                sample.pos.y,
                math.rad(sample.rot_deg),
                sample.scale.x,
                sample.scale.y,
                part.anchor.x,
                part.anchor.y
            )
        end
    end
end

function love.keypressed(key)
    if data.anims[key] ~= nil then
        state.anim = key
        state.clock = 0.0
    end
end
]==]

---@param project_name string sanitized
---@param sprite_dir string sanitized
---@param default_anim string|nil
---@return string main.lua text
local function build_main(project_name, sprite_dir, default_anim)
    local text = MAIN_TEMPLATE
    text = text:gsub('@@PROJECT@@', project_name)
    text = text:gsub('@@SPRITE_DIR@@', sprite_dir)
    text = text:gsub('@@DEFAULT_ANIM@@', default_anim or '')
    return text
end

---@param project_name string sanitized
---@param width integer
---@param height integer
---@return string conf.lua text
local function build_conf(project_name, width, height)
    local title = lua_quote(project_name) or "'character'"
    return table.concat({
        '-- Generated by diver games/love2d/character.lua.',
        'function love.conf(t)',
        '    t.identity = ' .. title,
        "    t.version = '11.5'",
        '    t.window.title = ' .. title,
        '    t.window.width = ' .. tostring(width),
        '    t.window.height = ' .. tostring(height),
        'end',
        '',
    }, '\n')
end

---Generate a runnable LÖVE 11.5 project skeleton from a character.
---Validates first: hostile definitions are rejected with nil, err
---before any file text is produced.
---@param ch table character definition
---@param opts? Love2dCharacterOpts
---@return Love2dProject|nil project
---@return string|nil err
function M.build_project(ch, opts)
    opts = opts or {}
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, 'love2d: invalid character: ' .. tostring(verr[1])
    end
    local project_name = sanitize_name(opts.name or ch.name)
    local width = opts.width or 800
    local height = opts.height or 600
    if type(width) ~= 'number' or width ~= math.floor(width) or width < 1 or width > M.WINDOW_DIM_MAX then
        return nil, 'love2d: width out of range'
    end
    if type(height) ~= 'number' or height ~= math.floor(height) or height < 1 or height > M.WINDOW_DIM_MAX then
        return nil, 'love2d: height out of range'
    end
    local sprite_dir = opts.sprite_dir or 'assets'
    if type(sprite_dir) ~= 'string' or sprite_dir == '' or sprite_dir:find('%.%.') ~= nil then
        return nil, 'love2d: unsafe sprite_dir'
    end
    if next(ch.timelines) == nil then
        return nil, 'love2d: character has no timelines to bake'
    end
    local data, derr = build_data_table(ch)
    if data == nil then
        return nil, derr
    end
    local encoded = encode_value(data, 0)
    if encoded == nil then
        return nil, 'love2d: data table is not serializable'
    end
    local anims = {}
    for name in pairs(ch.timelines) do
        anims[#anims + 1] = name
    end
    table.sort(anims)
    local files = {
        { path = 'conf.lua', content = build_conf(project_name, width, height) },
        { path = 'main.lua', content = build_main(project_name, sprite_dir, data.default_anim) },
        {
            path = 'data.lua',
            content = '-- Generated by diver games/love2d/character.lua.\nreturn ' .. encoded .. '\n',
        },
    }
    return { project_name = project_name, files = files, anims = anims }, nil
end

---Honest capability report. LÖVE is a 2D framework: there is NO true
---3D here, and pseudo-3D (billboards, the g3d library) is out of scope
---for this module by design.
---@return { dims_2d: boolean, dims_3d: boolean, notes: string[] }
function M.capabilities()
    return {
        dims_2d = true,
        dims_3d = false,
        notes = {
            'Generates a runnable LÖVE 11.5 project skeleton (conf.lua + main.lua + data.lua).',
            'Timeline player bakes poses with shared.character.sample_pose(); sprites load from a directory.',
            'NO true 3D in LÖVE -- pseudo-3D (billboards/g3d) is out of scope for this module.',
        },
    }
end

return M
