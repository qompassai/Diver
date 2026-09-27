-- E2E honesty gate for games/blender: procedural scene generation,
-- one real headless still render, one real glTF export, and a batch
-- pass over a directory. This file is NOT part of the 16/16
-- validation/adversarial split; it proves the pipeline works against
-- the real Blender binary or reports honestly that it does not.
--
-- Run from the repo root:
--   nvim --headless -c "luafile tests/lua/blender_e2e.lua" -c "quit!"
local versions = require('games.blender.versions')
local render = require('games.blender.render')
local export = require('games.blender.export')
local batch = require('games.blender.batch')

local failures = {}

local function check(name, cond, detail)
    if cond then
        print('ok: ' .. name)
    else
        failures[#failures + 1] = name
        print('FAIL: ' .. name .. (detail and (' -- ' .. detail) or ''))
    end
end

---@param path string
---@return integer? width
---@return integer? height
local function png_dimensions(path)
    local file = io.open(path, 'rb')

    if file == nil then
        return nil, nil
    end

    local header = file:read(32)
    file:close()

    if header == nil or #header < 24 or header:sub(1, 8) ~= '\137PNG\r\n\26\n' then
        return nil, nil
    end

    local width = 0
    for i = 1, 4 do
        width = width * 256 + header:byte(16 + i)
    end

    local height = 0
    for i = 1, 4 do
        height = height * 256 + header:byte(20 + i)
    end

    return width, height
end

local SCENE_SCRIPT = table.concat({
    'import bpy, os',
    'out = os.environ["BLENDER_SCENE_OUTPUT"]',
    'cam = bpy.data.objects.get("Camera")',
    'bpy.ops.object.empty_add(location=(0.0, 0.0, 0.0))',
    'target = bpy.context.active_object',
    'target.name = "DiverE2ETarget"',
    'cam.location = (6.0, -6.0, 4.0)',
    'track = cam.constraints.new("TRACK_TO")',
    'track.target = target',
    'track.track_axis = "TRACK_NEGATIVE_Z"',
    'track.up_axis = "UP_Y"',
    'bpy.context.scene.camera = cam',
    'bpy.ops.wm.save_as_mainfile(filepath=out)',
    'print("DIVER_SCENE_OK " + out)',
}, '\n') .. '\n'

local workdir = vim.fn.tempname() .. '-blender-e2e'
vim.fn.mkdir(workdir, 'p')

print('e2e workdir: ' .. workdir)

-- 0. Timeout mechanism: the kill switch every render relies on.
local t0 = vim.uv.hrtime()
local sleep_result = vim.system({ 'sleep', '30' }, { text = true, timeout = 500 }):wait()
local sleep_dt = (vim.uv.hrtime() - t0) / 1e9
check(
    'vim.system timeout kills a 30s sleep quickly',
    sleep_dt < 5.0 and sleep_result.code ~= 0,
    ('took %.2fs, code %s'):format(sleep_dt, tostring(sleep_result.code))
)

-- 1. Binary present and version-guarded.
local bin, bin_err = versions.ensure_installed()
check('blender installed', bin ~= nil, tostring(bin_err))

if bin == nil then
    print('E2E ABORTED: no blender binary -- nothing below ran')
    vim.cmd('cquit 1')
    return
end

local version_ok, version_err = versions.check_version()
check('version guard passes', version_ok, tostring(version_err))

-- 2. Procedural scene: cube + light + camera, saved as .blend.
local blend_path = workdir .. '/e2e.blend'
local scene_script_path = workdir .. '/gen_scene.py'
assert(vim.fn.writefile(vim.split(SCENE_SCRIPT, '\n', { plain = true }), scene_script_path) == 0)

t0 = vim.uv.hrtime()
local scene_result = vim.system({ bin, '-b', '--python', scene_script_path }, {
    text = true,
    timeout = 120000,
    env = { BLENDER_SCENE_OUTPUT = blend_path },
}):wait()
local scene_dt = (vim.uv.hrtime() - t0) / 1e9

local scene_stdout = scene_result.stdout or ''
check(
    'procedural scene generated',
    scene_result.code == 0 and scene_stdout:find('DIVER_SCENE_OK', 1, true) ~= nil,
    ('exit %d in %.2fs: %s'):format(scene_result.code, scene_dt, (scene_result.stderr or ''):match('^([^\r\n]*)') or '')
)
print(('scene generation wall time: %.2fs'):format(scene_dt))

local blend_stat = vim.uv.fs_stat(blend_path)
check('scene .blend exists and is nonzero', blend_stat ~= nil and blend_stat.size > 0)

if blend_stat == nil then
    print('E2E ABORTED: no .blend to render')
    vim.cmd('cquit 1')
    return
end

-- 3. One real still render, 96x64.
t0 = vim.uv.hrtime()
local info, render_err = render.render_still(blend_path, workdir .. '/still', { width = 96, height = 64, samples = 8 })
local render_dt = (vim.uv.hrtime() - t0) / 1e9
check('render_still succeeds', info ~= nil, tostring(render_err))
print(('still render wall time: %.2fs'):format(render_dt))

if info ~= nil then
    local png_path = info.saved[1]
    local png_stat = vim.uv.fs_stat(png_path)
    check('rendered PNG exists and is nonzero', png_stat ~= nil and png_stat.size > 0, png_path)

    local w, h = png_dimensions(png_path)
    check('rendered PNG is 96x64', w == 96 and h == 64, ('got %sx%s'):format(tostring(w), tostring(h)))
end

-- 4. One real glTF export.
t0 = vim.uv.hrtime()
local glb_path, glb_err = export.export_glb(blend_path, workdir .. '/e2e.glb')
local glb_dt = (vim.uv.hrtime() - t0) / 1e9
check('export_glb succeeds', glb_path ~= nil, tostring(glb_err))
print(('glb export wall time: %.2fs'):format(glb_dt))

if glb_path ~= nil then
    local file = io.open(glb_path, 'rb')
    local magic = file and file:read(4)
    if file then
        file:close()
    end
    check('exported file has glTF magic', magic == 'glTF', glb_path)
end

-- 5. Batch over a directory holding the .blend.
local batch_dir = workdir .. '/batch_in'
local batch_out = workdir .. '/batch_out'
vim.fn.mkdir(batch_dir, 'p')
vim.fn.mkdir(batch_out, 'p')
assert(vim.fn.writefile({}, batch_dir .. '/placeholder.txt') == 0)
vim.uv.fs_copyfile(blend_path, batch_dir .. '/e2e.blend')

t0 = vim.uv.hrtime()
local summary, batch_err = batch.run(batch_dir, 'export_glb', { output_dir = batch_out })
local batch_dt = (vim.uv.hrtime() - t0) / 1e9
check(
    'batch export_glb 1/1 succeeds',
    summary ~= nil and summary.total == 1 and summary.succeeded == 1 and summary.failed == 0,
    tostring(batch_err)
)
print(('batch wall time: %.2fs'):format(batch_dt))

-- 6. One real turntable: 4 frames, 64x64.
local sprites = require('games.blender.sprites')

t0 = vim.uv.hrtime()
local tt, tt_err =
    render.render_turntable(blend_path, workdir .. '/tt', { frames = 4, width = 64, height = 64, samples = 8 })
local tt_dt = (vim.uv.hrtime() - t0) / 1e9
check('render_turntable succeeds', tt ~= nil, tostring(tt_err))
print(('turntable wall time: %.2fs'):format(tt_dt))

if tt ~= nil then
    check('turntable returns 4 frames', #tt.frames == 4, ('got %d'):format(#tt.frames))

    local tt_dims_ok = true

    for _, frame_path in ipairs(tt.frames) do
        local st = vim.uv.fs_stat(frame_path)
        local w, h = png_dimensions(frame_path)

        if st == nil or st.size == 0 or w ~= 64 or h ~= 64 then
            tt_dims_ok = false
        end
    end

    check('turntable frames are real 64x64 PNGs', tt_dims_ok)
end

-- 7. One real sprite bake: 4 frames, 64x64, single-row strip + manifest.
t0 = vim.uv.hrtime()
local manifest, bake_err = sprites.bake(
    blend_path,
    workdir .. '/strip.png',
    workdir .. '/strip.json',
    { frames = 4, width = 64, height = 64, samples = 8 }
)
local bake_dt = (vim.uv.hrtime() - t0) / 1e9
check('sprites.bake succeeds', manifest ~= nil, tostring(bake_err))
print(('sprite bake wall time: %.2fs'):format(bake_dt))

if manifest ~= nil then
    local valid, valid_err = sprites.validate_manifest(manifest)
    check('bake manifest validates', valid, tostring(valid_err))
    check('bake manifest has 4 frames', #manifest.frames == 4, ('got %d'):format(#manifest.frames))

    local strip_w, strip_h = png_dimensions(workdir .. '/strip.png')
    check(
        'baked strip is 256x64',
        strip_w == 256 and strip_h == 64,
        ('got %sx%s'):format(tostring(strip_w), tostring(strip_h))
    )

    local rect_ok = true

    for i, frame in ipairs(manifest.frames) do
        if frame.x ~= (i - 1) * 64 or frame.y ~= 0 or frame.w ~= 64 or frame.h ~= 64 then
            rect_ok = false
        end
    end

    check('manifest frame rects tile the strip', rect_ok)
end

print(('\ne2e workdir kept at %s for inspection'):format(workdir))

if #failures > 0 then
    print(('\nblender_e2e: %d FAILURES'):format(#failures))
    vim.cmd('cquit 1')
else
    print('\nblender_e2e: ALL CHECKS PASSED')
end
