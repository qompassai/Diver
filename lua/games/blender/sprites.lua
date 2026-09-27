-- #################################################################
-- /qompassai/Diver/lua/games/blender/sprites.lua
-- Qompass AI Blender Sprites
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
-- 2D sprite-sheet baking: render N frames (the scene's own
-- animation, or a camera turntable) with a fixed orthographic
-- camera preset, then pack the frames into one PNG strip plus a
-- JSON frame manifest.
--
-- Compositing choice (documented per the build brief): we do NOT
-- shell out to ImageMagick `montage`. The packer is pure Lua: the
-- bake script writes each frame as raw top-first RGBA bytes, and
-- Lua packs them into a single-row PNG strip with a hand-rolled
-- PNG writer (stored, i.e. uncompressed, deflate blocks + CRC32 +
-- Adler-32, all arithmetic -- no bit operators, no zlib binding).
-- That keeps sprite baking working with zero host image tooling
-- beyond Blender itself.
--
-- Frame manifest format (for consumers):
--   {
--     "format": "diver-blender-sprites",
--     "version": 1,
--     "frame_width": 128, "frame_height": 128,
--     "strip": "hero.png",
--     "frames": [
--       { "index": 0, "x": 0, "y": 0, "w": 128, "h": 128,
--         "source": "frame_0000.raw" }
--     ]
--   }
-- The strip is a single row: frame `index` occupies the rectangle
-- (index * frame_width, 0, frame_width, frame_height). `source`
-- names the intermediate raw file (kept only when keep_raw is set).
local config = require('games.blender.config')
local versions = require('games.blender.versions')

local M = {}

local SPRITE_DIM_MAX = 1024
local SPRITE_FRAMES_MAX = 64
local DEFLATE_BLOCK_MAX = 65535
local ADLER_MOD = 65521
local CRC_POLY = 0xEDB88320

---@class BlenderSpriteOpts
---@field frames? integer Frame count (default 8)
---@field width? integer Frame width in pixels (default 128)
---@field height? integer Frame height in pixels (default 128)
---@field mode? string 'anim' (scene animation) or 'turntable' (orbiting camera)
---@field samples? integer Render samples (default config.render.samples_default)
---@field engine? string 'cycles' (default) or 'eevee'
---@field ortho_scale? number Orthographic camera scale (default 6.0)
---@field keep_raw? boolean Keep intermediate .raw frame files (default false)
---@field timeout_ms? integer Per-bake timeout (default config.render.timeout_ms_default)

---@param a number
---@param b number
---@return integer xor
local function bxor32_fallback(a, b)
    local result, bit = 0, 1

    for _ = 1, 32 do
        if (a % 2) ~= (b % 2) then
            result = result + bit
        end

        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit = bit * 2
    end

    return result
end

-- LuaJIT's bit library makes the per-byte CRC loop ~60x faster than the
-- arithmetic fallback. The module only ever runs inside Neovim (LuaJIT),
-- so `bit` is always present; the fallback keeps the math correct on
-- any interpreter if that ever changes.
local has_bit, bit_lib = pcall(require, 'bit')

---@type integer[]?
local crc_table = nil

---@return integer[] table
local function get_crc_table()
    if crc_table ~= nil then
        return crc_table
    end

    local built = {}

    for index = 0, 255 do
        local entry = index

        for _ = 1, 8 do
            if entry % 2 == 1 then
                -- Unsigned arithmetic here: bit.bxor returns signed values
                -- on LuaJIT, which would corrupt the table via arithmetic
                -- right shifts below.
                entry = bxor32_fallback(math.floor(entry / 2), CRC_POLY)
            else
                entry = math.floor(entry / 2)
            end
        end

        built[index] = entry
    end

    crc_table = built

    return built
end

---@param data string
---@return integer crc Unsigned 32-bit CRC
local function crc32(data)
    local table_ = get_crc_table()

    if has_bit then
        -- bit.rshift is a logical shift, so signedness of the LuaJIT
        -- bit results never leaks in; only the final value is
        -- normalized to unsigned for the chunk writer.
        local crc = 0xFFFFFFFF

        for index = 1, #data do
            local key = bit_lib.bxor(bit_lib.band(crc, 0xFF), data:byte(index))
            crc = bit_lib.bxor(table_[key], bit_lib.rshift(crc, 8))
        end

        return bit_lib.bxor(crc, 0xFFFFFFFF) % 4294967296
    end

    local crc = 0xFFFFFFFF

    for index = 1, #data do
        local byte = data:byte(index)
        crc = bxor32_fallback(table_[bxor32_fallback(crc % 256, byte)], math.floor(crc / 256))
    end

    return bxor32_fallback(crc, 0xFFFFFFFF)
end

---@param data string
---@return integer adler
local function adler32(data)
    local low, high = 1, 0

    for index = 1, #data do
        low = (low + data:byte(index)) % ADLER_MOD
        high = (high + low) % ADLER_MOD
    end

    return high * 65536 + low
end

---@param value integer
---@return string 4 bytes, big-endian
local function be32(value)
    local bytes = {}

    for shift = 24, 0, -8 do
        bytes[#bytes + 1] = string.char(math.floor(value / (2 ^ shift)) % 256)
    end

    return table.concat(bytes)
end

---@param ctype string 4-byte chunk type
---@param data string Chunk payload
---@return string chunk
local function png_chunk(ctype, data)
    return be32(#data) .. ctype .. data .. be32(crc32(ctype .. data))
end

---Encode RGBA pixels (top-row-first, width*height*4 bytes) as a PNG
---using stored (uncompressed) deflate blocks. Pure Lua: no zlib.
---@param width integer
---@param height integer
---@param pixels string width*height*4 raw RGBA bytes, top row first
---@return string? png
---@return string? err
function M.png_encode_rgba(width, height, pixels)
    if type(width) ~= 'number' or width ~= math.floor(width) or width < 1 then
        return nil, 'blender: png width must be a positive integer'
    end

    if type(height) ~= 'number' or height ~= math.floor(height) or height < 1 then
        return nil, 'blender: png height must be a positive integer'
    end

    if type(pixels) ~= 'string' or #pixels ~= width * height * 4 then
        return nil, 'blender: pixels must be exactly width*height*4 bytes'
    end

    local row_bytes = width * 4
    local scanlines = {}

    for row = 1, height do
        scanlines[#scanlines + 1] = '\0' .. pixels:sub((row - 1) * row_bytes + 1, row * row_bytes)
    end

    local raw = table.concat(scanlines)
    local blocks = {}
    local offset = 1

    while offset <= #raw do
        local piece = raw:sub(offset, offset + DEFLATE_BLOCK_MAX - 1)
        local last = offset + #piece > #raw
        local length = #piece

        blocks[#blocks + 1] = string.char(last and 1 or 0)
            .. string.char(length % 256, math.floor(length / 256) % 256)
            .. string.char((0xFFFF - length) % 256, math.floor((0xFFFF - length) / 256) % 256)
            .. piece

        offset = offset + #piece
    end

    local zlib_stream = '\120\1' .. table.concat(blocks) .. be32(adler32(raw))
    local ihdr = be32(width) .. be32(height) .. string.char(8, 6, 0, 0, 0)

    return '\137PNG\r\n\26\n' .. png_chunk('IHDR', ihdr) .. png_chunk('IDAT', zlib_stream) .. png_chunk('IEND', ''), nil
end

---@class BlenderSpriteFrame
---@field width integer
---@field height integer
---@field pixels string Raw RGBA bytes, top row first
---@field source? string Intermediate file name (for the manifest)

---@param frames table[] Frame list
---@param width integer Frame width
---@param height integer Frame height
---@return string? strip_pixels Concatenated single-row RGBA pixels
---@return string? err
local function pack_single_row(frames, width, height)
    local row_bytes = width * 4
    local rows = {}

    for row = 1, height do
        rows[row] = {}
    end

    for index, frame in ipairs(frames) do
        if frame.width ~= width or frame.height ~= height then
            local msg = ('frame %d is %dx%d, expected %dx%d'):format(index, frame.width, frame.height, width, height)
            return nil, 'blender: ' .. msg
        end

        if type(frame.pixels) ~= 'string' or #frame.pixels ~= width * height * 4 then
            return nil, ('blender: frame %d has a short pixel buffer'):format(index)
        end

        for row = 1, height do
            rows[row][#rows[row] + 1] = frame.pixels:sub((row - 1) * row_bytes + 1, row * row_bytes)
        end
    end

    local strip_rows = {}

    for row = 1, height do
        strip_rows[#strip_rows + 1] = table.concat(rows[row])
    end

    return table.concat(strip_rows), nil
end

---@param frames table[] Frame list
---@param width integer Frame width
---@param height integer Frame height
---@return table[] manifest_frames
local function manifest_frame_list(frames, width, height)
    local manifest_frames = {}

    for index, frame in ipairs(frames) do
        manifest_frames[index] = {
            index = index - 1,
            x = (index - 1) * width,
            y = 0,
            w = width,
            h = height,
            source = frame.source,
        }
    end

    return manifest_frames
end

---Pack animation frames side-by-side into one horizontal PNG strip and
---build its JSON manifest. Pure Lua: no blender, no image libraries.
---@param frames table[] Each frame: {width,height,pixels,source?}
---@param strip_name string File name recorded in the manifest
---@return table? packed {png=string, manifest=table}
---@return string? err
function M.pack_strip(frames, strip_name)
    if type(frames) ~= 'table' or #frames == 0 then
        return nil, 'blender: pack_strip needs at least one frame'
    end

    if type(strip_name) ~= 'string' or strip_name == '' then
        return nil, 'blender: strip_name must be a non-empty string'
    end

    local width = frames[1].width
    local height = frames[1].height

    if type(width) ~= 'number' or width < 1 or type(height) ~= 'number' or height < 1 then
        return nil, 'blender: first frame has invalid dimensions'
    end

    local strip_pixels, pack_err = pack_single_row(frames, width, height)

    if strip_pixels == nil then
        return nil, pack_err
    end

    local png, png_err = M.png_encode_rgba(width * #frames, height, strip_pixels)

    if png == nil then
        return nil, png_err
    end

    return {
        png = png,
        manifest = {
            format = 'diver-blender-sprites',
            version = config.manifest_version,
            frame_width = width,
            frame_height = height,
            strip = strip_name,
            frames = manifest_frame_list(frames, width, height),
        },
    },
        nil
end

---Validate a decoded sprite manifest table.
---@param manifest any
---@return boolean ok
---@return string? err
function M.validate_manifest(manifest)
    if type(manifest) ~= 'table' then
        return false, 'blender: manifest must be a table'
    end

    if manifest.format ~= 'diver-blender-sprites' then
        return false, 'blender: manifest format must be diver-blender-sprites'
    end

    if manifest.version ~= config.manifest_version then
        return false, 'blender: manifest version mismatch'
    end

    local function positive_int(value, name)
        if type(value) ~= 'number' or value ~= math.floor(value) or value < 1 then
            return false, ('blender: manifest %s must be a positive integer'):format(name)
        end

        return true, nil
    end

    local ok, err = positive_int(manifest.frame_width, 'frame_width')
    if not ok then
        return false, err
    end

    ok, err = positive_int(manifest.frame_height, 'frame_height')
    if not ok then
        return false, err
    end

    if type(manifest.strip) ~= 'string' or manifest.strip == '' then
        return false, 'blender: manifest strip must be a non-empty string'
    end

    if type(manifest.frames) ~= 'table' or #manifest.frames == 0 then
        return false, 'blender: manifest frames must be a non-empty list'
    end

    local strip_width = manifest.frame_width * #manifest.frames

    for index, frame in ipairs(manifest.frames) do
        if type(frame) ~= 'table' then
            return false, ('blender: manifest frame %d must be a table'):format(index)
        end

        if frame.index ~= index - 1 then
            return false, ('blender: manifest frame %d has wrong index'):format(index)
        end

        for _, field in ipairs({ 'x', 'y', 'w', 'h' }) do
            local value = frame[field]

            if type(value) ~= 'number' or value ~= math.floor(value) or value < 0 then
                local msg = ('frame %d field %s must be a non-negative integer'):format(index, field)
                return false, 'blender: manifest ' .. msg
            end
        end

        if frame.w ~= manifest.frame_width or frame.h ~= manifest.frame_height then
            return false, ('blender: manifest frame %d size mismatch'):format(index)
        end

        if frame.x + frame.w > strip_width or frame.y + frame.h > manifest.frame_height then
            return false, ('blender: manifest frame %d exceeds strip bounds'):format(index)
        end
    end

    return true, nil
end

---Static bake script: fixed orthographic camera preset (track-to an
---empty at the origin), N frames rendered to raw RGBA files.
---Parameters arrive via environment variables only.
---The per-frame body of the bake script: pose, render to a temp PNG,
---reload it as an image datablock (Render Result is empty in background
---mode), flip the rows into a raw RGBA buffer, and delete the temp file.
---@return string[] lines
local function bake_frame_lines()
    return {
        'for i in range(frames):',
        '    if mode == "turntable":',
        '        rig.rotation_euler[2] = 2.0 * math.pi * i / frames',
        '    else:',
        '        scene.frame_set(scene.frame_start + i)',
        '    bpy.context.view_layer.update()',
        '    tmp = os.path.join(outdir, "_tmp_%04d.png" % i)',
        '    scene.render.filepath = tmp',
        '    bpy.ops.render.render(write_still=True)',
        '    img = bpy.data.images.load(tmp)',
        '    px = img.pixels[:]',
        '    out = bytearray(width * height * 4)',
        '    for row in range(height):',
        '        src = height - 1 - row',
        '        base = row * row_len',
        '        for col in range(row_len):',
        '            v = px[src * row_len + col]',
        '            out[base + col] = max(0, min(255, int(v * 255.0 + 0.5)))',
        '    bpy.data.images.remove(img)',
        '    os.remove(tmp)',
        '    path = os.path.join(outdir, "frame_%04d.raw" % i)',
        '    f = open(path, "wb")',
        '    f.write(bytes(out))',
        '    f.close()',
    }
end

---@return string script
function M.build_bake_script()
    local lines = {
        'import bpy, math, os',
        'outdir = os.environ["BLENDER_SPRITE_OUTDIR"]',
        'width = int(os.environ.get("BLENDER_SPRITE_WIDTH", "128"))',
        'height = int(os.environ.get("BLENDER_SPRITE_HEIGHT", "128"))',
        'frames = int(os.environ.get("BLENDER_SPRITE_FRAMES", "8"))',
        'mode = os.environ.get("BLENDER_SPRITE_MODE", "turntable")',
        'samples = int(os.environ.get("BLENDER_SPRITE_SAMPLES", "32"))',
        'ortho = float(os.environ.get("BLENDER_SPRITE_ORTHO", "6.0"))',
        'scene = bpy.context.scene',
        'engine = os.environ.get("BLENDER_SPRITE_ENGINE", "cycles")',
        'if engine == "eevee":',
        '    scene.render.engine = "BLENDER_EEVEE"',
        'else:',
        '    scene.render.engine = "CYCLES"',
        '    scene.cycles.device = "CPU"',
        'scene.render.resolution_x = width',
        'scene.render.resolution_y = height',
        'scene.render.resolution_percentage = 100',
        'scene.render.film_transparent = True',
        'scene.render.image_settings.file_format = "PNG"',
        'scene.render.image_settings.color_mode = "RGBA"',
        'cycles = getattr(scene, "cycles", None)',
        'if cycles is not None:',
        '    cycles.samples = samples',
        'eevee = getattr(scene, "eevee", None)',
        'if eevee is not None:',
        '    eevee.taa_render_samples = samples',
        'bpy.ops.object.empty_add(location=(0.0, 0.0, 0.0))',
        'target = bpy.context.active_object',
        'target.name = "DiverSpriteTarget"',
        'bpy.ops.object.empty_add(location=(0.0, 0.0, 0.0))',
        'rig = bpy.context.active_object',
        'rig.name = "DiverSpriteRig"',
        'cam_data = bpy.data.cameras.new("DiverOrthoCam")',
        'cam_data.type = "ORTHO"',
        'cam_data.ortho_scale = ortho',
        'cam = bpy.data.objects.new("DiverOrthoCam", cam_data)',
        'scene.collection.objects.link(cam)',
        'cam.parent = rig',
        'cam.location = (0.0, -10.0, 2.0)',
        'track = cam.constraints.new("TRACK_TO")',
        'track.target = target',
        'track.track_axis = "TRACK_NEGATIVE_Z"',
        'track.up_axis = "UP_Y"',
        'scene.camera = cam',
        'row_len = width * 4',
    }

    for _, line in ipairs(bake_frame_lines()) do
        lines[#lines + 1] = line
    end

    lines[#lines + 1] = 'print("DIVER_SPRITES_OK")'

    return table.concat(lines, '\n') .. '\n'
end

---@param value any
---@param name string
---@param minimum number
---@param maximum number
---@return number? validated
---@return string? err
local function check_bounded(value, name, minimum, maximum)
    if type(value) ~= 'number' then
        return nil, ('blender: %s must be a number, got %s'):format(name, type(value))
    end

    if value ~= math.floor(value) or value < minimum or value > maximum then
        local msg = ('%s=%s out of range [%s, %s]'):format(name, tostring(value), tostring(minimum), tostring(maximum))
        return nil, 'blender: ' .. msg
    end

    return value, nil
end

---@param opts? BlenderSpriteOpts
---@return table? normalized
---@return string? err
local function normalize_bake_opts(opts)
    local o = opts or {}
    local caps = config.render

    local frames, frames_err = check_bounded(o.frames or 8, 'frames', 1, SPRITE_FRAMES_MAX)
    if frames == nil then
        return nil, frames_err
    end

    local width, width_err = check_bounded(o.width or 128, 'width', 1, SPRITE_DIM_MAX)
    if width == nil then
        return nil, width_err
    end

    local height, height_err = check_bounded(o.height or 128, 'height', 1, SPRITE_DIM_MAX)
    if height == nil then
        return nil, height_err
    end

    local mode = o.mode or 'turntable'
    if mode ~= 'anim' and mode ~= 'turntable' then
        return nil, 'blender: mode must be "anim" or "turntable"'
    end

    local engine = o.engine or 'cycles'
    if engine ~= 'cycles' and engine ~= 'eevee' then
        return nil, 'blender: engine must be "cycles" or "eevee"'
    end

    local samples, samples_err = check_bounded(o.samples or caps.samples_default, 'samples', 1, caps.samples_max)
    if samples == nil then
        return nil, samples_err
    end

    local ortho = o.ortho_scale or 6.0
    if type(ortho) ~= 'number' or ortho < 0.5 or ortho > 100.0 then
        return nil, 'blender: ortho_scale must be within [0.5, 100.0]'
    end

    local timeout_ms, timeout_err =
        check_bounded(o.timeout_ms or caps.timeout_ms_default, 'timeout_ms', 1000, caps.timeout_ms_max)
    if timeout_ms == nil then
        return nil, timeout_err
    end

    return {
        frames = frames,
        width = width,
        height = height,
        mode = mode,
        samples = samples,
        engine = engine,
        ortho_scale = ortho,
        keep_raw = o.keep_raw == true,
        timeout_ms = timeout_ms,
    },
        nil
end

---Run the bake Python script with the validated binary and options.
---@param bin string Validated blender binary path
---@param blend string .blend file path
---@param workdir string Scratch directory for the bake script and .raw frames
---@param normalized table Normalized bake options
---@return nil
---@return string? err
local function run_bake_script(bin, blend, workdir, normalized)
    local script_path = workdir .. '/bake.py'

    if vim.fn.writefile(vim.split(M.build_bake_script(), '\n', { plain = true }), script_path) ~= 0 then
        return nil, 'blender: could not write bake script'
    end

    local env = {
        BLENDER_SPRITE_OUTDIR = workdir,
        BLENDER_SPRITE_WIDTH = tostring(normalized.width),
        BLENDER_SPRITE_HEIGHT = tostring(normalized.height),
        BLENDER_SPRITE_FRAMES = tostring(normalized.frames),
        BLENDER_SPRITE_MODE = normalized.mode,
        BLENDER_SPRITE_SAMPLES = tostring(normalized.samples),
        BLENDER_SPRITE_ENGINE = normalized.engine,
        BLENDER_SPRITE_ORTHO = tostring(normalized.ortho_scale),
    }

    local result, spawn_err = versions.system_wait({ bin, '-b', blend, '--python', script_path }, {
        text = true,
        timeout = normalized.timeout_ms,
        env = env,
    })

    if result == nil then
        return nil, spawn_err
    end

    if result.code ~= 0 then
        local detail = (result.stderr or ''):match('^([^\r\n]*)') or ''
        return nil, ('blender sprite bake failed (exit %d): %s'):format(result.code, detail)
    end

    -- Blender can exit 0 even when the bake script raised (the traceback
    -- goes to stderr), so the marker is the real success signal.
    local marker = 'DIVER_SPRITES_OK'

    if not ((result.stdout or ''):find(marker, 1, true) or (result.stderr or ''):find(marker, 1, true)) then
        local detail = (result.stderr or ''):match('^([^\r\n]*)') or ''
        return nil, 'blender: bake script did not report success: ' .. detail
    end

    return nil, nil
end

---@param workdir string Scratch directory holding frame_%04d.raw files
---@param normalized table Normalized bake options
---@return table? frames List of {width,height,pixels,source}
---@return string? err
local function collect_raw_frames(workdir, normalized)
    local expected_bytes = normalized.width * normalized.height * 4
    local frames = {}

    for index = 0, normalized.frames - 1 do
        local raw_path = ('%s/frame_%04d.raw'):format(workdir, index)
        local file = io.open(raw_path, 'rb')

        if file == nil then
            return nil, 'blender: bake did not produce ' .. raw_path
        end

        local pixels = file:read('*all')
        file:close()

        if #pixels ~= expected_bytes then
            local size_msg = ('blender: frame %d has %d bytes, expected %d'):format(index, #pixels, expected_bytes)
            return nil, size_msg
        end

        local source = normalized.keep_raw and ('frame_%04d.raw'):format(index) or nil
        frames[#frames + 1] = { width = normalized.width, height = normalized.height, pixels = pixels, source = source }
    end

    return frames, nil
end

---@param packed table {png=string, manifest=table} from pack_strip
---@param output_png string Destination .png path
---@param manifest_path string Destination .json path
---@return nil
---@return string? err
local function write_pack_outputs(packed, output_png, manifest_path)
    local png_file = io.open(output_png, 'wb')

    if png_file == nil then
        return nil, 'blender: could not write ' .. output_png
    end

    png_file:write(packed.png)
    png_file:close()

    local manifest_file = io.open(manifest_path, 'w')

    if manifest_file == nil then
        return nil, 'blender: could not write ' .. manifest_path
    end

    manifest_file:write(vim.json.encode(packed.manifest))
    manifest_file:close()

    return nil, nil
end

---@param blend string .blend file path
---@param output_png string Destination sprite strip .png
---@param manifest_path string Destination manifest .json
---@return string? err
local function check_bake_paths(blend, output_png, manifest_path)
    if type(blend) ~= 'string' or blend == '' then
        return 'blender: blend must be a non-empty path'
    end

    if type(output_png) ~= 'string' or output_png == '' then
        return 'blender: output_png must be a non-empty path'
    end

    if type(manifest_path) ~= 'string' or manifest_path == '' then
        return 'blender: manifest_path must be a non-empty path'
    end

    return nil
end

---Bake animation frames to an orthographic sprite strip PNG plus a JSON
---manifest. Frames render inside blender (Cycles CPU by default, or
---eevee), packing and PNG writing are pure Lua. The scratch workdir is
---removed on any failure, and on success unless keep_raw is set.
---@param blend string .blend file path
---@param output_png string Destination sprite strip .png
---@param manifest_path string Destination manifest .json
---@param opts? BlenderSpriteOpts
---@return table? manifest Validated sprite manifest
---@return string? err
function M.bake(blend, output_png, manifest_path, opts)
    local version_ok, version_err = versions.check_version()

    if not version_ok then
        return nil, version_err
    end

    local bin, bin_err = versions.ensure_installed()

    if bin == nil then
        return nil, bin_err
    end

    local path_err = check_bake_paths(blend, output_png, manifest_path)

    if path_err ~= nil then
        return nil, path_err
    end

    local normalized, norm_err = normalize_bake_opts(opts)

    if normalized == nil then
        return nil, norm_err
    end

    local workdir = vim.fn.tempname() .. '-blender-sprites'
    vim.fn.mkdir(workdir, 'p')

    local function fail(err)
        vim.fn.delete(workdir, 'rf')
        return nil, err
    end

    local _, run_err = run_bake_script(bin, blend, workdir, normalized)

    if run_err ~= nil then
        return fail(run_err)
    end

    local frames, frames_err = collect_raw_frames(workdir, normalized)

    if frames == nil then
        return fail(frames_err)
    end

    local packed, pack_err = M.pack_strip(frames, vim.fs.basename(output_png))

    if packed == nil then
        return fail(pack_err)
    end

    local _, write_err = write_pack_outputs(packed, output_png, manifest_path)

    if write_err ~= nil then
        return fail(write_err)
    end

    if not normalized.keep_raw then
        vim.fn.delete(workdir, 'rf')
    end

    local valid, valid_err = M.validate_manifest(packed.manifest)

    if not valid then
        return nil, 'blender: packed manifest failed validation: ' .. tostring(valid_err)
    end

    return packed.manifest, nil
end

return M
