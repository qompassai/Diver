-- #################################################################
-- /qompassai/Diver/lua/games/aseprite/import.lua
-- Qompass AI Aseprite AI-Art Import Pipeline
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
-- Turns AI-generated art into clean, Aseprite-ready sprite PNGs:
-- background removal, nearest-neighbor downscale to a frame size, and
-- (ImageMagick path) palette quantization. The original file is never
-- overwritten; output lands next to it as `<stem>_sprite.png`.
--
-- Two processor paths, detected at runtime (never assumed):
--   A. Aseprite CLI  — a generated Lua script strips the background via
--      the documented Image:pixels() API; `--scale` resizes. Assumes the
--      local Aseprite honors `--scale <factor>` (disable via config
--      `scale_via_cli = false` if yours does not); quantization stays a
--      manual step (Sprite > Color Mode > Indexed) on this path.
--   B. ImageMagick  — one argv call: fuzz key-out, +dither -colors,
--      -filter point -resize. Full pipeline, no Aseprite needed.
--   C. Neither      — honest "no image processor available" error.
--
-- Pure helpers (no vim.*) are unit-testable under plain Lua: ext
-- validation, output path, PNG dimension parse, script text, argv
-- building, scale-factor math.
local config = require('games.aseprite.config')
local autil = require('games.aseprite.util')
local shared_util = require('games.shared.util')

local M = {}

M.IMAGE_EXTS = { '.png', '.jpg', '.jpeg', '.webp', '.bmp' }
M.BATCH_FILES_MAX = 64
M.INPUT_MEGAPIXELS_MAX = 16
M.MAGICK_TIMEOUT_MS = 120000
M.PNG_MIN_BYTES = 33

---@class AsepriteImportPaths
---@field bin string|nil Aseprite binary path, or nil
---@field magick string|nil ImageMagick binary path, or nil

---Validate an image extension against the allowlist. Pure.
---@param path string
---@return boolean
function M.valid_image_ext(path)
    if type(path) ~= 'string' then
        return false
    end
    local lowered = path:lower()
    for _, ext in ipairs(M.IMAGE_EXTS) do
        if lowered:sub(-#ext) == ext then
            return true
        end
    end
    return false
end

---Compute the output path: `<stem>_sprite.png` next to the source.
---Pure (no fs access).
---@param input string
---@return string|nil out
---@return string|nil err
function M.output_path_for(input)
    if type(input) ~= 'string' or input == '' then
        return nil, 'input path required'
    end
    local stem = input:match('^(.*)%.[^%.%/\\]+$') or input
    local out = stem .. '_sprite.png'
    if out == input then
        return nil, 'output would overwrite input'
    end
    return out, nil
end

---Parse PNG dimensions from the IHDR chunk. Pure: works on raw bytes,
---no image library needed. Returns nil when the header is not a PNG
---or is truncated (caller treats as "unknown size"). Byte math only --
---no string.unpack, which does not exist on LuaJIT (Matt's runtime).
---@param bytes string first >= 33 bytes of the file
---@return integer|nil width
---@return integer|nil height
function M.parse_png_dimensions(bytes)
    if type(bytes) ~= 'string' or #bytes < M.PNG_MIN_BYTES then
        return nil, nil
    end
    if bytes:sub(1, 8) ~= '\137PNG\r\n\26\n' then
        return nil, nil
    end
    -- IHDR: length(4)=13, type(4)='IHDR', width(4 BE), height(4 BE).
    if bytes:sub(13, 16) ~= 'IHDR' then
        return nil, nil
    end
    local function be32(pos)
        local b1, b2, b3, b4 = bytes:byte(pos, pos + 3)
        if b1 == nil then
            return nil
        end
        return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
    end
    local w, h = be32(17), be32(21)
    if w == nil or h == nil or w < 1 or h < 1 or w > 65535 or h > 65535 then
        return nil, nil
    end
    return w, h
end

---Read just enough of a file to parse PNG dimensions. Returns nil,nil
---on any failure (never raises).
---@param path string
---@return integer|nil width
---@return integer|nil height
local function read_png_dimensions(path)
    local fh, open_err = io.open(path, 'rb')
    if not fh then
        return nil, nil
    end
    local bytes = fh:read(M.PNG_MIN_BYTES)
    fh:close()
    if not bytes then
        return nil, nil
    end
    return M.parse_png_dimensions(bytes)
end

---Scale factor so the longest side lands on frame_size_px. Pure.
---@param width integer|nil
---@param height integer|nil
---@param frame_size_px integer
---@return number factor (1.0 when size unknown)
function M.scale_factor(width, height, frame_size_px)
    if type(width) ~= 'number' or type(height) ~= 'number' then
        return 1.0
    end
    local longest = math.max(width, height)
    if longest < 1 or frame_size_px < 1 then
        return 1.0
    end
    return frame_size_px / longest
end

---Map a configured key-color name to a hex string. Pure.
---@param name string
---@return string hex
function M.key_color_hex(name)
    local map = { black = '#000000', white = '#ffffff', magenta = '#ff00ff', green = '#00ff00' }
    return map[name] or '#000000'
end

---Build the Aseprite Lua script that strips the key background.
---Pure string generation; the script uses Aseprite's documented
---Image:pixels() iterator and app.pixelColor helpers. Batch-safe: no UI
---calls (app.alert is UI-only and fails under --batch), color-mode gate
---before the rgba* extractors (on indexed images the int is a palette
---index), mutations inside app.transaction so an error rolls back.
---@param opts { key_hex: string, fuzz: integer }
---@return string script
function M.build_aseprite_script(opts)
    local lines = {
        '-- Generated by diver games/aseprite/import.lua — background removal.',
        '-- Strips near-key pixels to transparent with a feathered edge.',
        'local spr = app.sprite',
        'assert(spr ~= nil, "No sprite open.")',
        'assert(spr.colorMode == ColorMode.RGB, "need RGB color mode, got " .. tostring(spr.colorMode))',
        string.format('local KEY = "%s"', opts.key_hex),
        string.format('local FUZZ = %d', opts.fuzz or 12),
        'local function hex_to_rgb(hex)',
        '  return tonumber(hex:sub(2,3),16), tonumber(hex:sub(4,5),16), tonumber(hex:sub(6,7),16)',
        'end',
        'local kr, kg, kb = hex_to_rgb(KEY)',
        'local function near_key(r, g, b)',
        '  return math.abs(r-kr) <= FUZZ and math.abs(g-kg) <= FUZZ and math.abs(b-kb) <= FUZZ',
        'end',
        'app.transaction("diver: strip key background", function()',
        '  for _, layer in ipairs(spr.layers) do',
        '    for _, cel in ipairs(layer.cels) do',
        '      local img = cel.image',
        '      for pixel in img:pixels() do',
        '        local c = pixel()',
        '        local r, g, b = app.pixelColor.rgbaR(c), app.pixelColor.rgbaG(c), app.pixelColor.rgbaB(c)',
        '        if near_key(r, g, b) then',
        '          pixel(app.pixelColor.rgba(0, 0, 0, 0))',
        '        end',
        '      end',
        '    end',
        '  end',
        'end)',
        'print("OK background stripped")',
    }
    return table.concat(lines, '\n')
end

---Build the ImageMagick argv for the full pipeline. Pure.
---@param opts { magick: string, input: string, output: string, key_hex: string, fuzz: integer, frame_size_px: integer, colors: integer }
---@return string[] argv
function M.build_magick_argv(opts)
    return {
        opts.magick,
        opts.input,
        '-fuzz', tostring(opts.fuzz) .. '%',
        '-transparent', opts.key_hex,
        '+dither',
        '-colors', tostring(opts.colors),
        '-filter', 'point',
        '-resize', tostring(opts.frame_size_px) .. 'x' .. tostring(opts.frame_size_px) .. '>',
        opts.output,
    }
end

---Detect available image processors. vim-dependent (executable lookup).
---@return AsepriteImportPaths
function M.detect_processors()
    local magick = vim.fn.executable('magick') == 1 and 'magick'
        or (vim.fn.executable('convert') == 1 and 'convert' or nil)
    return { bin = autil.find_binary(), magick = magick }
end

---Validate an import request before any processing. vim-dependent (fs).
---@param input string
---@return string|nil err
local function validate_input(input)
    if type(input) ~= 'string' or input == '' then
        return 'no input file given'
    end
    if not M.valid_image_ext(input) then
        return 'unsupported image type: ' .. input
    end
    local stat = vim.uv.fs_stat(input)
    if not stat then
        return 'cannot stat input: ' .. input
    end
    return nil
end

---Run one file through the pipeline.
---@param input string
---@param paths AsepriteImportPaths
---@return string|nil out clean output path
---@return string|nil via processor note (only when out is non-nil)
---@return string|nil err (only when out is nil)
function M.import_file(input, paths)
    local cfg = config.ai_import or {}
    local input_err = validate_input(input)
    if input_err then
        return nil, nil, input_err
    end
    local out, path_err = M.output_path_for(input)
    if not out then
        return nil, nil, path_err
    end
    local frame_size = cfg.frame_size_px or 128
    local key_hex = M.key_color_hex(cfg.bg_key or 'black')
    local fuzz = cfg.bg_fuzz_percent or 8

    if paths.magick then
        local argv = M.build_magick_argv({
            magick = paths.magick,
            input = input,
            output = out,
            key_hex = key_hex,
            fuzz = fuzz,
            frame_size_px = frame_size,
            colors = cfg.quantize_colors or 64,
        })
        local result = vim.system(argv, { timeout = M.MAGICK_TIMEOUT_MS }):wait()
        if result.code ~= 0 then
            return nil, nil, 'ImageMagick failed: ' .. (result.stderr or ''):sub(1, 300)
        end
        return out, 'ImageMagick', nil
    end

    if paths.bin then
        local w, h = read_png_dimensions(input)
        if w and h and (w * h) > M.INPUT_MEGAPIXELS_MAX * 1000000 then
            return nil, nil, string.format('input too large (%dx%d); limit is %d MP', w, h, M.INPUT_MEGAPIXELS_MAX)
        end
        local script = M.build_aseprite_script({ key_hex = key_hex, fuzz = fuzz * 3 })
        local script_path = vim.fn.tempname() .. '_diver_bgremove.lua'
        local fh = io.open(script_path, 'w')
        if not fh then
            return nil, nil, 'cannot write temp script'
        end
        fh:write(script)
        fh:close()
        local cmd = { paths.bin, '-b', input, '--script', script_path }
        if cfg.scale_via_cli ~= false then
            local factor = M.scale_factor(w, h, frame_size)
            cmd[#cmd + 1] = '--scale'
            cmd[#cmd + 1] = string.format('%.3f', factor)
        end
        vim.list_extend(cmd, { '--save-as', out })
        local result = vim.system(cmd, { timeout = M.MAGICK_TIMEOUT_MS }):wait()
        os.remove(script_path)
        if result.code ~= 0 then
            return nil, nil, 'Aseprite import failed: ' .. (result.stderr or ''):sub(1, 300)
        end
        return out, 'Aseprite (quantize manually: Sprite > Color Mode > Indexed)', nil
    end

    return nil, nil, 'no image processor available (need Aseprite or ImageMagick on PATH)'
end

---Interactive single-file import.
function M.import_art()
    local input = shared_util.trim(vim.fn.input('AI art image to import: ', '', 'file'))
    if input == '' then
        return
    end
    input = vim.fn.expand(input)
    local paths = M.detect_processors()
    local out, via, err = M.import_file(input, paths)
    if not out then
        vim.notify('Aseprite import: ' .. tostring(err), vim.log.levels.ERROR)
        return
    end
    local cfg = config.ai_import or {}
    vim.notify('Aseprite import finished: ' .. out .. ' [via ' .. tostring(via) .. ']', vim.log.levels.INFO)
    if cfg.auto_open_in_editor ~= false and paths.bin then
        vim.fn.jobstart({ paths.bin, out }, { detach = true })
    end
end

---Batch import: run the pipeline over every image in a directory.
function M.batch_import()
    local dir = shared_util.trim(vim.fn.input('Directory of AI art to import: ', '', 'dir'))
    if dir == '' then
        return
    end
    dir = vim.fn.expand(dir)
    local paths = M.detect_processors()
    local done, failed = 0, 0
    local failures = {}
    local count = 0
    for name, ftype in vim.fs.dir(dir) do
        if ftype == 'file' and M.valid_image_ext(name) then
            count = count + 1
            if count > M.BATCH_FILES_MAX then
                failures[#failures + 1] = 'batch limit reached (' .. M.BATCH_FILES_MAX .. ' files)'
                break
            end
            local _, _, err = M.import_file(dir .. '/' .. name, paths)
            if err then
                failed = failed + 1
                failures[#failures + 1] = name .. ': ' .. err
            else
                done = done + 1
            end
        end
    end
    local msg = string.format('Aseprite batch import: %d done, %d failed', done, failed)
    if #failures > 0 then
        msg = msg .. '\n' .. table.concat(failures, '\n'):sub(1, 2000)
    end
    vim.notify(msg, failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end

return M
