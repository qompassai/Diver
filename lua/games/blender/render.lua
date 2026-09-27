-- #################################################################
-- /qompassai/Diver/lua/games/blender/render.lua
-- Qompass AI Blender Render
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
-- Headless rendering through `blender -b`. Still frames and camera
-- turntables share one contract: argv is built as a list (never a
-- shell string), every numeric option is range-checked against the
-- caps in config.lua, and blender's own "Saved:" lines are parsed
-- to prove the output landed on disk. Missing binary or an
-- unsupported version fails closed before anything spawns.
local config = require('games.blender.config')
local versions = require('games.blender.versions')

local M = {}

---@alias BlenderRenderEngine
---| 'cycles' # CYCLES on CPU: headless-safe everywhere, no GPU/EGL needed
---| 'eevee' # BLENDER_EEVEE: faster, but needs GPU or EGL libraries present

---@class BlenderStillOpts
---@field frame? integer Frame to render (default 1)
---@field width? integer Output width in pixels (default 512)
---@field height? integer Output height in pixels (default 512)
---@field samples? integer Render samples (default config.render.samples_default)
---@field engine? BlenderRenderEngine Render engine (default 'cycles')
---@field timeout_ms? integer Per-render timeout (default config.render.timeout_ms_default)

---@class BlenderTurntableOpts
---@field frames? integer Frame count (default config.render.turntable_frames_default)
---@field width? integer Output width in pixels (default 512)
---@field height? integer Output height in pixels (default 512)
---@field samples? integer Render samples (default config.render.samples_default)
---@field engine? BlenderRenderEngine Render engine (default 'cycles')
---@field timeout_ms? integer Per-run timeout (default config.render.timeout_ms_default)

---@param value any
---@param name string
---@param minimum integer
---@param maximum integer
---@return integer? validated
---@return string? err
local function check_integer(value, name, minimum, maximum)
    if type(value) ~= 'number' or value ~= math.floor(value) then
        return nil, ('blender: %s must be an integer, got %s'):format(name, tostring(value))
    end

    if value < minimum or value > maximum then
        return nil, ('blender: %s=%d out of range [%d, %d]'):format(name, value, minimum, maximum)
    end

    return value, nil
end

---@param value any
---@return BlenderRenderEngine? engine
---@return string? err
local function check_engine(value)
    local engine = value or 'cycles'

    if engine ~= 'cycles' and engine ~= 'eevee' then
        return nil, 'blender: engine must be "cycles" or "eevee"'
    end

    return engine, nil
end

---@param opts? BlenderStillOpts
---@return table? normalized
---@return string? err
local function normalize_still_opts(opts)
    local o = opts or {}
    local caps = config.render

    local frame, frame_err = check_integer(o.frame or 1, 'frame', 1, 1000000)
    if frame == nil then
        return nil, frame_err
    end

    local width, width_err = check_integer(o.width or 512, 'width', 1, caps.width_max)
    if width == nil then
        return nil, width_err
    end

    local height, height_err = check_integer(o.height or 512, 'height', 1, caps.height_max)
    if height == nil then
        return nil, height_err
    end

    local samples, samples_err = check_integer(o.samples or caps.samples_default, 'samples', 1, caps.samples_max)
    if samples == nil then
        return nil, samples_err
    end

    local timeout_ms, timeout_err =
        check_integer(o.timeout_ms or caps.timeout_ms_default, 'timeout_ms', 1000, caps.timeout_ms_max)
    if timeout_ms == nil then
        return nil, timeout_err
    end

    local engine, engine_err = check_engine(o.engine)

    if engine == nil then
        return nil, engine_err
    end

    return {
        frame = frame,
        width = width,
        height = height,
        samples = samples,
        engine = engine,
        timeout_ms = timeout_ms,
    },
        nil
end

---Python applied to the loaded scene. Static text: the only dynamic
---values are width, height, and samples -- validated integers
---formatted with %d, never string-interpolated from user input.
---Engine is a validated 'cycles'|'eevee' token selecting a static
---branch, never pasted into code.
---@param width integer Validated output width
---@param height integer Validated output height
---@param samples integer Validated sample count
---@param engine BlenderRenderEngine Validated engine token
---@return string snippet
local function scene_setup_snippet(width, height, samples, engine)
    assert(type(width) == 'number' and width == math.floor(width))
    assert(type(height) == 'number' and height == math.floor(height))
    assert(type(samples) == 'number' and samples == math.floor(samples))
    assert(engine == 'cycles' or engine == 'eevee')

    local engine_lines

    if engine == 'cycles' then
        engine_lines = 'scene.render.engine = "CYCLES"\n' .. 'scene.cycles.device = "CPU"\n'
    else
        engine_lines = 'scene.render.engine = "BLENDER_EEVEE"\n'
    end

    return (
        'import bpy\n'
        .. 'scene = bpy.context.scene\n'
        .. engine_lines
        .. ('scene.render.resolution_x = %d\n'):format(width)
        .. ('scene.render.resolution_y = %d\n'):format(height)
        .. 'scene.render.resolution_percentage = 100\n'
        .. 'scene.render.image_settings.file_format = "PNG"\n'
        .. 'cycles = getattr(scene, "cycles", None)\n'
        .. 'if cycles is not None:\n'
        .. ('    cycles.samples = %d\n'):format(samples)
        .. 'eevee = getattr(scene, "eevee", None)\n'
        .. 'if eevee is not None:\n'
        .. ('    eevee.taa_render_samples = %d\n'):format(samples)
    )
end

---@param text string Blender stdout/stderr text
---@return string[] paths Every "Saved:" path blender reported
function M.parse_saved_lines(text)
    local paths = {}

    if type(text) ~= 'string' or text == '' then
        return paths
    end

    for line in text:gmatch('[^\r\n]+') do
        -- Blender 5.x prefixes log lines with a timestamp and category
        -- ("00:01.061  render           | Saved: '...'"), so match
        -- "Saved:" anywhere in the line, not just at the start.
        local raw = line:match('Saved:%s*(.-)%s*$')

        if raw ~= nil and raw ~= '' then
            -- Blender quotes paths with single quotes; strip one matching pair.
            local stripped = raw:match("^'(.*)'$") or raw

            if stripped ~= '' then
                paths[#paths + 1] = stripped
            end
        end
    end

    return paths
end

---Build the argv for a single still render. Pure: no binary needed,
---so tests can hammer it with hostile paths.
---@param bin string Blender binary path
---@param blend string .blend file path (one argv element, never a shell string)
---@param output string Output path prefix (blender appends the frame suffix)
---@param opts? BlenderStillOpts
---@return string[]? argv
---@return string? err
function M.build_still_argv(bin, blend, output, opts)
    if type(bin) ~= 'string' or bin == '' then
        return nil, 'blender: bin must be a non-empty path'
    end

    if type(blend) ~= 'string' or blend == '' then
        return nil, 'blender: blend must be a non-empty path'
    end

    if type(output) ~= 'string' or output == '' then
        return nil, 'blender: output must be a non-empty path'
    end

    local normalized, norm_err = normalize_still_opts(opts)

    if normalized == nil then
        return nil, norm_err
    end

    return {
        bin,
        '-b',
        blend,
        '--python-expr',
        scene_setup_snippet(normalized.width, normalized.height, normalized.samples, normalized.engine),
        '-o',
        output,
        '-f',
        tostring(normalized.frame),
    },
        nil
end

---@param argv string[]
---@param timeout_ms integer
---@return string[]? saved
---@return string? err
local function run_and_collect_saved(argv, timeout_ms)
    local result, spawn_err = versions.system_wait(argv, { text = true, timeout = timeout_ms })

    if result == nil then
        return nil, spawn_err
    end

    if result.code ~= 0 then
        local detail = (result.stderr or ''):match('^([^\r\n]*)') or ''
        return nil, ('blender render failed (exit %d): %s'):format(result.code, detail)
    end

    local saved = M.parse_saved_lines((result.stdout or '') .. '\n' .. (result.stderr or ''))

    if #saved == 0 then
        return nil, 'blender exited 0 but reported no "Saved:" output lines'
    end

    for _, path in ipairs(saved) do
        local stat = vim.uv.fs_stat(path)

        if stat == nil or stat.size == 0 then
            return nil, 'blender reported Saved: ' .. path .. ' but the file is missing or empty'
        end
    end

    return saved, nil
end

---Render one still frame headless. Version-guarded; fails closed on
---a missing binary.
---@param blend string .blend file path
---@param output string Output path prefix
---@param opts? BlenderStillOpts
---@return table? info { saved = string[] }
---@return string? err
function M.render_still(blend, output, opts)
    local version_ok, version_err = versions.check_version()

    if not version_ok then
        return nil, version_err
    end

    local bin, bin_err = versions.ensure_installed()

    if bin == nil then
        return nil, bin_err
    end

    local argv, argv_err = M.build_still_argv(bin, blend, output, opts)

    if argv == nil then
        return nil, argv_err
    end

    local normalized = assert(normalize_still_opts(opts))
    local saved, run_err = run_and_collect_saved(argv, normalized.timeout_ms)

    if saved == nil then
        return nil, run_err
    end

    return { saved = saved }, nil
end

---Static turntable script: builds its own orbiting camera rig (an
---empty at the origin, camera parented to it with a track-to
---constraint), so the result is deterministic for any .blend.
---All parameters arrive via environment variables, never via code
---interpolation.
---@return string script
function M.build_turntable_script()
    return table.concat({
        'import bpy, math, os',
        'outdir = os.environ["BLENDER_TT_OUTDIR"]',
        'frames = int(os.environ.get("BLENDER_TT_FRAMES", "8"))',
        'width = int(os.environ.get("BLENDER_TT_WIDTH", "512"))',
        'height = int(os.environ.get("BLENDER_TT_HEIGHT", "512"))',
        'samples = int(os.environ.get("BLENDER_TT_SAMPLES", "32"))',
        'scene = bpy.context.scene',
        'engine = os.environ.get("BLENDER_TT_ENGINE", "cycles")',
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
        'cycles = getattr(scene, "cycles", None)',
        'if cycles is not None:',
        '    cycles.samples = samples',
        'eevee = getattr(scene, "eevee", None)',
        'if eevee is not None:',
        '    eevee.taa_render_samples = samples',
        'bpy.ops.object.empty_add(location=(0.0, 0.0, 0.0))',
        'rig = bpy.context.active_object',
        'rig.name = "DiverTurntableRig"',
        'cam_data = bpy.data.cameras.new("DiverTurntableCam")',
        'cam = bpy.data.objects.new("DiverTurntableCam", cam_data)',
        'scene.collection.objects.link(cam)',
        'cam.parent = rig',
        'cam.location = (6.0, 0.0, 3.0)',
        'track = cam.constraints.new("TRACK_TO")',
        'track.target = rig',
        'track.track_axis = "TRACK_NEGATIVE_Z"',
        'track.up_axis = "UP_Y"',
        'scene.camera = cam',
        'for i in range(frames):',
        '    rig.rotation_euler[2] = 2.0 * math.pi * i / frames',
        '    bpy.context.view_layer.update()',
        '    scene.render.filepath = os.path.join(outdir, "frame_%04d.png" % (i + 1))',
        '    bpy.ops.render.render(write_still=True)',
    }, '\n') .. '\n'
end

---@param o table Raw turntable options
---@return table? normalized
---@return string? err
local function normalize_turntable_opts(o)
    local caps = config.render

    local frames_default = caps.turntable_frames_default
    local frames, frames_err = check_integer(o.frames or frames_default, 'frames', 1, caps.turntable_frames_max)
    if frames == nil then
        return nil, frames_err
    end

    local width, width_err = check_integer(o.width or 512, 'width', 1, caps.width_max)
    if width == nil then
        return nil, width_err
    end

    local height, height_err = check_integer(o.height or 512, 'height', 1, caps.height_max)
    if height == nil then
        return nil, height_err
    end

    local samples, samples_err = check_integer(o.samples or caps.samples_default, 'samples', 1, caps.samples_max)
    if samples == nil then
        return nil, samples_err
    end

    local timeout_ms, timeout_err =
        check_integer(o.timeout_ms or caps.timeout_ms_default, 'timeout_ms', 1000, caps.timeout_ms_max)
    if timeout_ms == nil then
        return nil, timeout_err
    end

    local engine, engine_err = check_engine(o.engine)

    if engine == nil then
        return nil, engine_err
    end

    return {
        frames = frames,
        width = width,
        height = height,
        samples = samples,
        timeout_ms = timeout_ms,
        engine = engine,
    },
        nil
end

---Build the argv for a turntable run. Pure: no binary needed.
---@param bin string Blender binary path
---@param blend string .blend file path
---@param script_path string Turntable Python script path
---@param output_dir string Directory receiving frame_XXXX.png files
---@param opts? BlenderTurntableOpts
---@return string[]? argv
---@return string? err
---@return table? run_opts {timeout_ms, env, expected_frames}
function M.build_turntable_argv(bin, blend, script_path, output_dir, opts)
    if type(bin) ~= 'string' or bin == '' then
        return nil, 'blender: bin must be a non-empty path'
    end

    if type(blend) ~= 'string' or blend == '' then
        return nil, 'blender: blend must be a non-empty path'
    end

    if type(script_path) ~= 'string' or script_path == '' then
        return nil, 'blender: script_path must be a non-empty path'
    end

    if type(output_dir) ~= 'string' or output_dir == '' then
        return nil, 'blender: output_dir must be a non-empty path'
    end

    local normalized, norm_err = normalize_turntable_opts(opts or {})

    if normalized == nil then
        return nil, norm_err
    end

    return {
        bin,
        '-b',
        blend,
        '--python',
        script_path,
    },
        nil,
        {
            timeout_ms = normalized.timeout_ms,
            env = {
                BLENDER_TT_OUTDIR = output_dir,
                BLENDER_TT_FRAMES = tostring(normalized.frames),
                BLENDER_TT_WIDTH = tostring(normalized.width),
                BLENDER_TT_HEIGHT = tostring(normalized.height),
                BLENDER_TT_SAMPLES = tostring(normalized.samples),
                BLENDER_TT_ENGINE = normalized.engine,
            },
            expected_frames = normalized.frames,
        }
end

---Render a camera turntable: N stills orbiting the scene, written as
---frame_0001.png .. frame_NNNN.png under output_dir.
---@param blend string .blend file path
---@param output_dir string Directory receiving the frames (created when missing)
---@param opts? BlenderTurntableOpts
---@return table? info { frames = string[] }
---@return string? err
function M.render_turntable(blend, output_dir, opts)
    local version_ok, version_err = versions.check_version()

    if not version_ok then
        return nil, version_err
    end

    local bin, bin_err = versions.ensure_installed()

    if bin == nil then
        return nil, bin_err
    end

    if type(output_dir) ~= 'string' or output_dir == '' then
        return nil, 'blender: output_dir must be a non-empty path'
    end

    vim.fn.mkdir(output_dir, 'p')

    local script_path = vim.fn.tempname() .. '-blender-turntable.py'
    local written = vim.fn.writefile(vim.split(M.build_turntable_script(), '\n', { plain = true }), script_path)

    if written ~= 0 then
        return nil, 'blender: could not write turntable script to ' .. script_path
    end

    local argv, argv_err, run_opts = M.build_turntable_argv(bin, blend, script_path, output_dir, opts)

    if argv == nil then
        vim.fn.delete(script_path)
        return nil, argv_err
    end

    assert(run_opts ~= nil)
    local sys_opts = { text = true, timeout = run_opts.timeout_ms, env = run_opts.env }
    local result, spawn_err = versions.system_wait(argv, sys_opts)
    vim.fn.delete(script_path)

    if result == nil then
        return nil, spawn_err
    end

    if result.code ~= 0 then
        local detail = (result.stderr or ''):match('^([^\r\n]*)') or ''
        return nil, ('blender turntable failed (exit %d): %s'):format(result.code, detail)
    end

    local saved = M.parse_saved_lines((result.stdout or '') .. '\n' .. (result.stderr or ''))

    if #saved ~= run_opts.expected_frames then
        return nil, ('blender turntable reported %d Saved: lines, expected %d'):format(#saved, run_opts.expected_frames)
    end

    for _, path in ipairs(saved) do
        local stat = vim.uv.fs_stat(path)

        if stat == nil or stat.size == 0 then
            return nil, 'blender reported Saved: ' .. path .. ' but the file is missing or empty'
        end
    end

    return { frames = saved }, nil
end

return M
