-- #################################################################
-- /qompassai/Diver/lua/games/aseprite/character.lua
-- Qompass AI Aseprite Character Builder
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
-- Character definition -> Aseprite CLI sheet export. Generates a
-- batch-safe Aseprite Lua assembly script (one layer per part, part
-- PNGs imported, one tag per timeline with direction derived from
-- the timeline's loop mode) plus the exact CLI argv for
-- `aseprite -b --sheet ... --data ...`.
--
-- Reuses the pipeline knowledge in games/aseprite/import.lua: binary
-- discovery over the same names/env vars, `--batch` scripting, no UI
-- calls in generated scripts.
--
-- Honest scope: the assembly carries parts as layers and timelines as
-- tags; per-frame part transforms are sampled engine-side with
-- shared.character.sample_pose() from the definition. Pixel-accurate
-- per-frame baking of transformed parts needs a renderer -- see
-- games/blender/character.lua. Fails closed when the aseprite binary
-- is absent. Pure at require time.
local kit = require('games.shared.character')

local M = {}

M.BINARIES = { 'aseprite', 'Aseprite' }
M.ENV_NAMES = { 'ASEPRITE_BIN', 'NVIM_ASEPRITE_BIN' }
M.FRAMES_MAX = 4096
M.CANVAS_DIM_MAX = 4096
M.EXPORT_TIMEOUT_MS = 300000

---@class AsepriteCharacterOpts
---@field bin? string explicit aseprite binary override
---@field width? integer canvas width (default 256)
---@field height? integer canvas height (default 256)
---@field sheet_type? string '--sheet-type' value (default 'packed')

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

---Find the aseprite binary: explicit override, then env vars (same
---names as games/aseprite/config.lua), then PATH. Pure Lua.
---@param override string|nil
---@return string|nil bin
function M.find_binary(override)
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

---@param name string
---@return string safe single path segment
local function sanitize_name(name)
    local safe = tostring(name):gsub('[%c%z]', ''):gsub('[^%w%-_]', '_'):sub(1, 48)
    if safe == '' then
        return 'character'
    end
    return safe
end

---@param sprite string
---@param part_name string
---@return string|nil err
local function check_sprite_path(sprite, part_name)
    if type(sprite) ~= 'string' or sprite == '' then
        return "aseprite: part '" .. part_name .. "' needs a sprite PNG to assemble"
    end
    if sprite:sub(1, 1) == '/' or sprite:find('%.%.') ~= nil or sprite:find('%z') ~= nil then
        return "aseprite: unsafe sprite path for part '" .. part_name .. "'"
    end
    return nil
end

---@param ch table validated character
---@return table[]|nil tags { name, from, to, direction, fps }
---@return string|nil err
local function build_tags(ch)
    local names = {}
    for name in pairs(ch.timelines) do
        names[#names + 1] = name
    end
    table.sort(names)
    local tags, cursor = {}, 1
    for _, name in ipairs(names) do
        local tl = ch.timelines[name]
        local count = math.floor(tl.duration_sec * tl.fps + 1e-9) + 1
        if cursor + count - 1 > M.FRAMES_MAX then
            return nil, 'aseprite: total frame count exceeds cap'
        end
        local direction = 'forward'
        if tl.loop == 'pingpong' then
            direction = 'ping-pong'
        elseif tl.loop == true then
            direction = 'forward'
        end
        tags[#tags + 1] = {
            name = name,
            from = cursor,
            to = cursor + count - 1,
            direction = direction,
            fps = tl.fps,
            frames = count,
        }
        cursor = cursor + count
    end
    return tags, nil
end

local ASSEMBLY_TEMPLATE = [==[
-- Generated by diver games/aseprite/character.lua -- @@CHARACTER@@.
-- Batch-safe: no UI calls (app.alert is UI-only and fails under
-- --batch). Parameters arrive via --script-param (out, width, height,
-- partdir), never interpolated into this text.
-- Aseprite API notes: uses the documented scripting API (Sprite,
-- Layer, Cel, Image:drawImage, Tag, AniDir). Verify member names
-- against your Aseprite version; this is generated, not hand-tested.
local params = app.params
local out_path = params["out"] or "character.aseprite"
local canvas_w = tonumber(params["width"]) or 256
local canvas_h = tonumber(params["height"]) or 256
local part_dir = params["partdir"] or "."

local spr = Sprite(canvas_w, canvas_h)
spr.filename = out_path

@@LAYERS@@

-- Import each part PNG into frame 1 of its layer.
local function import_part(layer_name, file)
    local src = app.open(part_dir .. "/" .. file)
    assert(src ~= nil, "aseprite: cannot open " .. file)
    local src_img = src.cels[1].image
    app.activeSprite = spr
    local layer = nil
    for _, candidate in ipairs(spr.layers) do
        if candidate.name == layer_name then
            layer = candidate
        end
    end
    assert(layer ~= nil, "aseprite: missing layer " .. layer_name)
    local cel = spr:newCel(layer, 1, src_img, Point(0, 0))
    src:close()
    return cel
end

@@IMPORTS@@

-- Allocate the remaining frames, then tag one range per timeline.
local total_frames = @@TOTAL_FRAMES@@
for _ = 2, total_frames do
    spr:newFrame()
end

@@TAGS@@

spr:saveAs(out_path)
print("DIVER_ASEPRITE_OK " .. out_path)
]==]

---@param ch table validated character
---@param tags table[] from build_tags
---@return string script
local function render_assembly(ch, tags)
    local layer_lines = {}
    local ordered = {}
    for _, part in ipairs(ch.parts) do
        ordered[#ordered + 1] = part
    end
    table.sort(ordered, function(a, b)
        return a.zindex < b.zindex
    end)
    for _, part in ipairs(ordered) do
        layer_lines[#layer_lines + 1] = 'do'
        layer_lines[#layer_lines + 1] = '    local layer = spr:newLayer()'
        layer_lines[#layer_lines + 1] = '    layer.name = "' .. part.name:gsub('"', '\\"') .. '"'
        layer_lines[#layer_lines + 1] = 'end'
    end
    local import_lines = {}
    for _, part in ipairs(ordered) do
        import_lines[#import_lines + 1] = 'import_part("'
            .. part.name:gsub('"', '\\"')
            .. '", "'
            .. part.sprite:gsub('"', '\\"')
            .. '")'
    end
    local tag_lines = {}
    for _, tag in ipairs(tags) do
        local dir = 'AniDir.FORWARD'
        if tag.direction == 'ping-pong' then
            dir = 'AniDir.PING_PONG'
        end
        tag_lines[#tag_lines + 1] = 'do'
        tag_lines[#tag_lines + 1] = '    local tag = spr:newTag(' .. tag.from .. ', ' .. tag.to .. ')'
        tag_lines[#tag_lines + 1] = '    tag.name = "' .. tag.name:gsub('"', '\\"') .. '"'
        tag_lines[#tag_lines + 1] = '    tag.aniDir = ' .. dir
        tag_lines[#tag_lines + 1] = 'end'
    end
    local total = 0
    for _, tag in ipairs(tags) do
        total = tag.to
    end
    local text = ASSEMBLY_TEMPLATE
    text = text:gsub('@@CHARACTER@@', sanitize_name(ch.name))
    text = text:gsub('@@LAYERS@@', table.concat(layer_lines, '\n'))
    text = text:gsub('@@IMPORTS@@', table.concat(import_lines, '\n'))
    text = text:gsub('@@TAGS@@', table.concat(tag_lines, '\n'))
    text = text:gsub('@@TOTAL_FRAMES@@', tostring(total))
    return text
end

---Build the batch-safe Aseprite Lua assembly script. Static text
---plus sanitized part/layer names; runtime parameters (out path,
---canvas, part dir) arrive via --script-param. Pure.
---@param ch table character definition (validated first)
---@return string|nil script
---@return string|nil err
function M.build_assembly_script(ch)
    local ok, verr = kit.validate_character(ch)
    if not ok then
        return nil, 'aseprite: invalid character: ' .. tostring(verr[1])
    end
    if next(ch.timelines) == nil then
        return nil, 'aseprite: character has no timelines to tag'
    end
    for _, part in ipairs(ch.parts) do
        local perr = check_sprite_path(part.sprite, part.name)
        if perr ~= nil then
            return nil, perr
        end
    end
    local tags, terr = build_tags(ch)
    if tags == nil then
        return nil, terr
    end
    return render_assembly(ch, tags), nil
end

---Build the `aseprite -b --sheet` export argv. Pure: no binary needed.
---@param bin string aseprite binary path
---@param project_path string .aseprite file produced by the assembly script
---@param sheet_path string destination sheet PNG
---@param data_path string destination JSON data file
---@param opts? AsepriteCharacterOpts
---@return string[]|nil argv
---@return string|nil err
function M.build_sheet_argv(bin, project_path, sheet_path, data_path, opts)
    opts = opts or {}
    for _, p in ipairs({ bin, project_path, sheet_path, data_path }) do
        if type(p) ~= 'string' or p == '' or p:find('%z') ~= nil then
            return nil, 'aseprite: all paths must be non-empty strings'
        end
    end
    local sheet_type = opts.sheet_type or 'packed'
    if sheet_type ~= 'packed' and sheet_type ~= 'rows' and sheet_type ~= 'columns' then
        return nil, "aseprite: sheet_type must be 'packed', 'rows', or 'columns'"
    end
    return {
        bin,
        '-b',
        project_path,
        '--sheet',
        sheet_path,
        '--sheet-type',
        sheet_type,
        '--data',
        data_path,
        '--format',
        'json-array',
    },
        nil
end

---Assemble the character in Aseprite and export the sheet:
---write the assembly script, run it with --script-param, then run the
-----sheet export. Fails closed when the binary is absent or when not
---running inside Neovim.
---@param ch table character definition
---@param out_dir string output directory (created)
---@param opts? AsepriteCharacterOpts
---@return table|nil result { project, sheet, data }
---@return string|nil err
function M.export_sheet(ch, out_dir, opts)
    opts = opts or {}
    if type(out_dir) ~= 'string' or out_dir == '' or out_dir:find('%z') ~= nil then
        return nil, 'aseprite: out_dir required'
    end
    local script, serr = M.build_assembly_script(ch)
    if script == nil then
        return nil, serr
    end
    local bin = M.find_binary(opts.bin)
    if bin == nil then
        return nil, 'aseprite: binary not found (tried ' .. table.concat(M.BINARIES, ', ') .. '); cannot export sheet'
    end
    if vim == nil or vim.fn == nil or vim.system == nil then
        return nil, 'aseprite: sheet export requires Neovim (vim.system)'
    end
    local width = opts.width or 256
    local height = opts.height or 256
    if type(width) ~= 'number' or width ~= math.floor(width) or width < 1 or width > M.CANVAS_DIM_MAX then
        return nil, 'aseprite: width out of range'
    end
    if type(height) ~= 'number' or height ~= math.floor(height) or height < 1 or height > M.CANVAS_DIM_MAX then
        return nil, 'aseprite: height out of range'
    end
    local safe = sanitize_name(ch.name)
    vim.fn.mkdir(out_dir, 'p')
    local workdir = vim.fn.tempname() .. '-aseprite-character'
    vim.fn.mkdir(workdir, 'p')
    local script_path = workdir .. '/assemble.lua'
    if vim.fn.writefile(vim.split(script, '\n', { plain = true }), script_path) ~= 0 then
        vim.fn.delete(workdir, 'rf')
        return nil, 'aseprite: could not write assembly script'
    end
    local project_path = out_dir .. '/' .. safe .. '.aseprite'
    local sheet_path = out_dir .. '/' .. safe .. '_sheet.png'
    local data_path = out_dir .. '/' .. safe .. '_sheet.json'
    local function fail(err)
        vim.fn.delete(workdir, 'rf')
        return nil, err
    end
    local assemble = vim.system({
        bin,
        '-b',
        '--script',
        script_path,
        '--script-param',
        'out=' .. project_path,
        '--script-param',
        'width=' .. tostring(width),
        '--script-param',
        'height=' .. tostring(height),
        '--script-param',
        'partdir=' .. out_dir,
    }, { text = true, timeout = M.EXPORT_TIMEOUT_MS }):wait()
    if assemble.code ~= 0 then
        return fail('aseprite: assembly failed (exit ' .. assemble.code .. ')')
    end
    local argv, aerr = M.build_sheet_argv(bin, project_path, sheet_path, data_path, opts)
    if argv == nil then
        return fail(aerr)
    end
    local exported = vim.system(argv, { text = true, timeout = M.EXPORT_TIMEOUT_MS }):wait()
    vim.fn.delete(workdir, 'rf')
    if exported.code ~= 0 then
        return nil, 'aseprite: sheet export failed (exit ' .. exported.code .. ')'
    end
    return { project = project_path, sheet = sheet_path, data = data_path }, nil
end

---Honest capability report. 2D sheet pipeline only; per-frame part
---transforms stay in the definition for engine-side sampling.
---@return { dims_2d: boolean, dims_3d: boolean, notes: string[] }
function M.capabilities()
    return {
        dims_2d = true,
        dims_3d = false,
        notes = {
            'Builds a batch-safe Aseprite Lua assembly script + CLI sheet-export',
            'argv (--sheet with timeline-derived tags).',
            'Assembly carries parts as layers and timelines as tags; per-frame',
            'transforms are sampled engine-side via shared.character.sample_pose().',
            'Pixel-accurate per-frame baking of transformed parts needs a renderer;',
            'see games.blender.character.',
            'Fails closed when the aseprite binary is absent.',
        },
    }
end

return M
