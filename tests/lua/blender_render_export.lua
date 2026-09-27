-- Headless test for games/blender render/export/sprite arg building,
-- Saved:-line parsing, the pure-Lua PNG writer, and manifest
-- validation. Runs under headless Neovim nightly with the full
-- diver config:
--   nvim --headless -c "luafile tests/lua/blender_render_export.lua" -c "quit!"
-- from the repo root. Nothing here spawns blender; hostile paths are
-- exercised against the argv builders only.
--
-- Split: 10 validation checks, 10 adversarial checks
-- (grand total with blender_versions.lua: 18 validation, 18 adversarial).
local render = require('games.blender.render')
local export = require('games.blender.export')
local sprites = require('games.blender.sprites')

local pass_count, fail_count = 0, 0
local adversarial_pass, adversarial_fail = 0, 0

local function check(name, cond, adversarial, detail)
    if cond then
        pass_count = pass_count + 1
        if adversarial then
            adversarial_pass = adversarial_pass + 1
        end
    else
        fail_count = fail_count + 1
        if adversarial then
            adversarial_fail = adversarial_fail + 1
        end
        print('FAIL: ' .. name .. (detail and (' -- ' .. detail) or ''))
    end
end

-- Adversarial inputs are intentionally mistyped; as_any keeps the
-- test honest about what it is doing without tripping the strict
-- checker on the test file itself.
---@param value any
---@return any
local function as_any(value)
    return value
end

local BIN = '/opt/blender/blender'
local BLEND = '/tmp/scene.blend'
local OUT = '/tmp/still'

-- ============ validation ============
local argv, argv_err = render.build_still_argv(BIN, BLEND, OUT, nil)
check(
    'still argv default shape',
    argv ~= nil and argv[1] == BIN and argv[2] == '-b' and argv[3] == BLEND and argv[6] == '-o' and argv[7] == OUT,
    false,
    tostring(argv_err)
)

local argv2 = render.build_still_argv(BIN, BLEND, OUT, { frame = 7, width = 640, height = 480, samples = 64 })
local argv2_ok = argv2 ~= nil
    and argv2[4] == '--python-expr'
    and argv2[5]:find('resolution_x = 640', 1, true) ~= nil -- validated ints enter the snippet via %d
    and argv2[5]:find('resolution_y = 480', 1, true) ~= nil
    and argv2[5]:find('taa_render_samples = 64', 1, true) ~= nil
    and argv2[8] == '-f'
    and argv2[9] == '7'
check('still argv honors opts', argv2_ok)

local saved = render.parse_saved_lines("Fra:1 Mem:10.00M | Time:00:00.50\nSaved: '/tmp/still0001.png'\n")
check('parse_saved_lines strips quotes', #saved == 1 and saved[1] == '/tmp/still0001.png')

local saved2 = render.parse_saved_lines("Saved: /a/1.png\nnoise\nSaved: '/b/2.png'\n")
local saved2_ok = #saved2 == 2 and saved2[1] == '/a/1.png' and saved2[2] == '/b/2.png'
check('parse_saved_lines collects many, ignores noise', saved2_ok)

check(
    'parse_saved_lines handles blender 5.x timestamped log lines',
    (function()
        -- Exact shape observed from blender 5.2.2 LTS headless renders.
        local stdout = table.concat({
            '00:00.834  render           | Fra: 1 | Mem: 1M | Finished',
            "00:01.061  render           | Saved: '/tmp/out/still0001.png'",
            '00:01.062  render           | Time: 00:00.38 (Saving: 00:00.16)',
            '',
            'Blender quit',
        }, '\n')
        local parsed = render.parse_saved_lines(stdout)
        return #parsed == 1 and parsed[1] == '/tmp/out/still0001.png'
    end)()
)

local glb_script = export.build_script('glb')
local fbx_script = export.build_script('fbx')
check(
    'export scripts carry the right operators',
    glb_script ~= nil
        and glb_script:find('export_scene.gltf', 1, true) ~= nil
        and fbx_script ~= nil
        and fbx_script:find('export_scene.fbx', 1, true) ~= nil
)

local eargv, eargv_err = export.build_argv(BIN, BLEND, '/tmp/x.py')
local eargv_ok = eargv ~= nil
    and eargv[1] == BIN
    and eargv[2] == '-b'
    and eargv[3] == BLEND
    and eargv[4] == '--python'
    and eargv[5] == '/tmp/x.py'
check('export argv shape', eargv_ok, false, tostring(eargv_err))

-- 2x1 red frame + 2x1 green frame -> 4x1 strip.
local red = string.rep(string.char(255, 0, 0, 255), 2)
local green = string.rep(string.char(0, 255, 0, 255), 2)
local packed, packed_err = sprites.pack_strip({
    { width = 2, height = 1, pixels = red, source = 'frame_0000.raw' },
    { width = 2, height = 1, pixels = green, source = 'frame_0001.raw' },
}, 'strip.png')
local png_ok = packed ~= nil and packed.png:sub(1, 8) == '\137PNG\r\n\26\n'
local dims_ok = false

if png_ok then
    local w = 0
    for i = 1, 4 do
        w = w * 256 + packed.png:byte(16 + i)
    end
    local h = 0
    for i = 1, 4 do
        h = h * 256 + packed.png:byte(20 + i)
    end
    dims_ok = w == 4 and h == 1
end

-- Independent CRC32, pure arithmetic (no bit library): regression guard
-- for the LuaJIT signed-bit.bxor bug that once corrupted chunk CRCs.
local function arith_bxor32(a, b)
    local result, mult = 0, 1
    for _ = 1, 32 do
        if (a % 2) ~= (b % 2) then
            result = result + mult
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        mult = mult * 2
    end
    return result
end

local function arith_crc32(data)
    local crc = 0xFFFFFFFF
    for i = 1, #data do
        crc = arith_bxor32(crc, data:byte(i))
        for _ = 1, 8 do
            if crc % 2 == 1 then
                crc = arith_bxor32(math.floor(crc / 2), 0xEDB88320)
            else
                crc = math.floor(crc / 2)
            end
        end
    end
    return arith_bxor32(crc, 0xFFFFFFFF)
end

local crcs_ok = false

if png_ok then
    local pos = 9
    crcs_ok = true
    while pos < #packed.png do
        local length = 0
        for i = 0, 3 do
            length = length * 256 + packed.png:byte(pos + i)
        end
        local ctype = packed.png:sub(pos + 4, pos + 7)
        local chunk = packed.png:sub(pos + 4, pos + 7 + length)
        local stored = 0
        for i = 0, 3 do
            stored = stored * 256 + packed.png:byte(pos + 8 + length + i)
        end
        if arith_crc32(chunk) ~= stored then
            crcs_ok = false
            break
        end
        pos = pos + 12 + length
        if ctype == 'IEND' then
            break
        end
    end
end

check(
    'png_encode writes valid PNG (signature, IHDR, chunk CRCs)',
    png_ok and dims_ok and crcs_ok,
    false,
    tostring(packed_err)
)

local manifest_ok = false

if packed ~= nil then
    local manifest = packed.manifest
    local valid, _ = sprites.validate_manifest(manifest)
    manifest_ok = valid
        and manifest.frames[1].x == 0
        and manifest.frames[2].x == 2
        and manifest.strip == 'strip.png'
        and #manifest.frames == 2
end

check('pack_strip manifest validates with correct frame rects', manifest_ok)

local cyc_argv = render.build_still_argv(BIN, BLEND, OUT, { engine = 'cycles' })
local eevee_argv = render.build_still_argv(BIN, BLEND, OUT, { engine = 'eevee' })
check(
    'engine token selects a static branch',
    cyc_argv ~= nil
        and cyc_argv[5]:find('scene.render.engine = "CYCLES"', 1, true) ~= nil
        and eevee_argv ~= nil
        and eevee_argv[5]:find('scene.render.engine = "BLENDER_EEVEE"', 1, true) ~= nil
)

-- ============ adversarial ============
local hostile_blend = '/tmp/my scene"; $(rm -rf /); \'.blend'
local hargv = render.build_still_argv(BIN, hostile_blend, OUT, nil)
check('hostile blend path stays one argv element', hargv ~= nil and hargv[3] == hostile_blend, true)

local snippet_leaks = false

if hargv ~= nil then
    -- argv[5] is the --python-expr snippet: it must not contain the blend path.
    snippet_leaks = hargv[5]:find(hostile_blend, 1, true) ~= nil
end

check('python-expr carries no path bytes', hargv ~= nil and not snippet_leaks, true)

local over_samples, over_samples_err = render.build_still_argv(BIN, BLEND, OUT, as_any({ samples = 99999 }))
check('samples over cap rejected', over_samples == nil and over_samples_err ~= nil, true)

local zero_width, zero_width_err = render.build_still_argv(BIN, BLEND, OUT, as_any({ width = 0 }))
check('zero width rejected', zero_width == nil and zero_width_err ~= nil, true)

local evil_frame, evil_frame_err = render.build_still_argv(BIN, BLEND, OUT, as_any({ frame = '1;evil' }))
check('string frame rejected', evil_frame == nil and evil_frame_err ~= nil, true)

local hostile_out = '/tmp/x"; rm -rf /; ".glb'
local static_script = export.build_script('glb') or ''
check('export script is static: hostile output path absent', static_script:find(hostile_out, 1, true) == nil, true)

local short_png, short_err = sprites.png_encode_rgba(2, 2, 'short')
check('png_encode rejects short pixel buffer', short_png == nil and short_err ~= nil, true)

local bad_manifest = {
    format = 'diver-blender-sprites',
    version = 1,
    frame_width = 2,
    frame_height = 1,
    strip = 'strip.png',
    frames = {
        { index = 0, x = 0, y = 0, w = 2, h = 1 },
        { index = 1, x = 99, y = 0, w = 2, h = 1 },
    },
}
local bad_ok, bad_err = sprites.validate_manifest(bad_manifest)
check('manifest rejects frame outside strip bounds', not bad_ok and bad_err ~= nil, true)

local evil_engine, evil_engine_err = render.build_still_argv(BIN, BLEND, OUT, as_any({ engine = '"; rm -rf /; "' }))
check('hostile engine token rejected', evil_engine == nil and evil_engine_err ~= nil, true)

check('parse_saved_lines ignores empty Saved: quotes', #render.parse_saved_lines("Saved: ''\n") == 0, true)

print(
    string.format(
        '\nblender_render_export: %d passed, %d failed (adversarial %d/%d)',
        pass_count,
        fail_count,
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)

if fail_count > 0 then
    vim.cmd('cquit 1')
end
