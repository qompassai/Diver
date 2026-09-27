-- Headless test for the per-engine character modules (TRACK D-ENGINES).
-- Runs under plain Lua (all modules are pure at require time) and inside
-- headless Neovim with the full config. Covers capabilities() honesty,
-- generated-artifact schema validity, sample_pose integration with
-- hand-computed pose values, and adversarial inputs.
--
-- Split: 28 validation checks, 28 adversarial checks.
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

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

local character = require('games.shared.character')
local love2d_character = require('games.love2d.character')
local blender_character = require('games.blender.character')
local godot_character = require('games.godot.character')
local redot_character = require('games.redot.character')
local unity_character = require('games.unity.character')
local unreal_character = require('games.unreal.character')
local aseprite_character = require('games.aseprite.character')

local function notes_contain(cap, sub)
    for _, note in ipairs(cap.notes) do
        if note:find(sub, 1, true) then
            return true
        end
    end
    return false
end

local function file_by_path(files, path)
    for _, f in ipairs(files) do
        if f.path == path then
            return f.content
        end
    end
    return nil
end

-- Adversarial inputs are intentionally mistyped; as_any keeps the
-- test honest about what it is doing without tripping the strict
-- checker on the test file itself.
---@param value any
---@return any
local function as_any(value)
    return value
end

-- Test character: 'idle' bakes at fps=2 over 1s -> frames at t=0, 0.5, 1.
-- Hand-computed: at t=0.5, torso pos = (50, 25), rot = 45.
local ch = character.new_character('hero')
character.add_part(ch, {
    name = 'torso',
    anchor = { x = 0, y = 0 },
    zindex = 0,
    sprite = 'torso.png',
    tags = {},
})
character.add_part(ch, {
    name = 'head',
    anchor = { x = 8, y = 8 },
    zindex = 1,
    sprite = 'head.png',
    tags = {},
})
character.add_timeline(ch, 'idle', { loop = true, fps = 2, duration_sec = 1 })
character.set_keyframe(ch, 'idle', 'torso', { t = 0, pos = { x = 0, y = 0 }, rot_deg = 0 })
character.set_keyframe(ch, 'idle', 'torso', { t = 1, pos = { x = 100, y = 50 }, rot_deg = 90 })
character.add_timeline(ch, 'walk', { loop = 'pingpong', fps = 2, duration_sec = 1 })
character.set_keyframe(ch, 'walk', 'head', { t = 0, pos = { x = 0, y = 0 } })
character.set_keyframe(ch, 'walk', 'head', { t = 1, pos = { x = 20, y = 0 } })

-- ============ validation: love2d (5) ============

local love_cap = love2d_character.capabilities()
check('love2d capabilities: 2D yes, 3D no', love_cap.dims_2d == true and love_cap.dims_3d == false, false)
check(
    'love2d capabilities: honest no-true-3D note',
    notes_contain(love_cap, 'NO true 3D in LÖVE') and notes_contain(love_cap, 'g3d'),
    false
)

local project, project_err = love2d_character.build_project(ch, {})
check(
    'love2d build_project: conf.lua + main.lua + data.lua',
    project ~= nil
        and file_by_path(project.files, 'conf.lua') ~= nil
        and file_by_path(project.files, 'main.lua') ~= nil
        and file_by_path(project.files, 'data.lua') ~= nil,
    false,
    project_err
)

local conf_lua = project and file_by_path(project.files, 'conf.lua') or nil
local main_lua = project and file_by_path(project.files, 'main.lua') or nil
local data_lua = project and file_by_path(project.files, 'data.lua') or nil
check(
    'love2d conf.lua pins LÖVE 11.5; main.lua is a timeline player',
    conf_lua ~= nil
        and conf_lua:find("t.version = '11.5'", 1, true) ~= nil
        and conf_lua:find('hero', 1, true) ~= nil
        and main_lua ~= nil
        and main_lua:find('love.load', 1, true) ~= nil
        and main_lua:find('love.update', 1, true) ~= nil
        and main_lua:find('love.draw', 1, true) ~= nil
        and main_lua:find("require('data')", 1, true) ~= nil,
    false
)

local data_fn = data_lua and load(data_lua, 'data.lua', 't', {}) or nil
local data_ok = false
local data_table = nil
if data_fn ~= nil then
    data_ok, data_table = pcall(data_fn)
end
local baked_ok = data_ok
    and data_table.anims.idle.frames[2].parts.torso.pos.x == 50
    and data_table.anims.idle.frames[2].parts.torso.pos.y == 25
    and data_table.anims.idle.frames[2].parts.torso.rot_deg == 45
check('love2d data.lua: hand-computed baked pose (50, 25, rot 45)', baked_ok, false)

-- ============ validation: blender (5) ============

local blender_cap = blender_character.capabilities()
check('blender capabilities: native 2D and 3D', blender_cap.dims_2d == true and blender_cap.dims_3d == true, false)

local script2d = blender_character.build_2d_script()
check(
    'blender 2D script: env-driven, orthographic camera',
    script2d:find('DIVER_CHAR_JSON', 1, true) ~= nil
        and script2d:find("'ORTHO'", 1, true) ~= nil
        and script2d:find('DIVER_CHAR_OK', 1, true) ~= nil,
    false
)

local script3d = blender_character.build_3d_script()
check(
    'blender 3D script: armature construction',
    script3d:find('armatures.new', 1, true) ~= nil
        and script3d:find('DIVER_CHAR_OK', 1, true) ~= nil
        and script3d:find('keyframe_insert', 1, true) ~= nil,
    false
)

local argv, argv_err = blender_character.build_argv('/usr/bin/blender', '/tmp/build.py', nil)
check(
    'blender build_argv: argv-safe shape',
    argv ~= nil
        and argv[1] == '/usr/bin/blender'
        and argv[2] == '-b'
        and argv[3] == '--python'
        and argv[4] == '/tmp/build.py',
    false,
    argv_err
)

local manifest2d, manifest2d_err = blender_character.bake_pose_manifest(ch, {})
local pose_ok = manifest2d ~= nil
    and manifest2d.anims.idle.frames[2].parts.torso.pos.x == 50
    and manifest2d.anims.idle.frames[2].parts.torso.rot_deg == 45
check('blender bake_pose_manifest: hand-computed pose (50, rot 45)', pose_ok, false, manifest2d_err)

-- ============ validation: godot (4) ============

local godot_cap = godot_character.capabilities()
check(
    'godot capabilities: 2D yes, 3D via-interchange',
    godot_cap.dims_2d == true and godot_cap.dims_3d == 'via-interchange',
    false
)
check(
    'godot capabilities: honest headless-validation limit',
    notes_contain(godot_cap, 'Headless Godot import validation is limited'),
    false
)

local godot_bundle, godot_err = godot_character.build_interchange(ch, {})
local godot_manifest = godot_bundle and file_by_path(godot_bundle.files, 'manifest.json') or nil
local godot_tscn = godot_bundle and file_by_path(godot_bundle.files, 'hero.tscn') or nil
local godot_gd = godot_bundle and file_by_path(godot_bundle.files, 'import_hero.gd') or nil
check(
    'godot interchange: manifest.json + .tscn sketch + .gd stub',
    godot_manifest ~= nil and godot_tscn ~= nil and godot_gd ~= nil,
    false,
    godot_err
)
check(
    'godot artifacts: format tag, tscn nodes, baked pose values',
    godot_manifest ~= nil
        and godot_manifest:find('"format":"diver-character-godot"', 1, true) ~= nil
        and godot_manifest:find('"pos":[50,25]', 1, true) ~= nil
        and godot_manifest:find('"rot":45', 1, true) ~= nil
        and godot_tscn ~= nil
        and godot_tscn:find('[gd_scene', 1, true) ~= nil
        and godot_tscn:find('Sprite2D', 1, true) ~= nil
        and godot_gd ~= nil
        and godot_gd:find('manifest', 1, true) ~= nil,
    false
)

-- ============ validation: redot (3) ============

local redot_cap = redot_character.capabilities()
check(
    'redot capabilities: 2D yes, 3D via-interchange, honest notes',
    redot_cap.dims_2d == true and redot_cap.dims_3d == 'via-interchange' and notes_contain(redot_cap, 'Redot'),
    false
)

local redot_bundle, redot_err = redot_character.build_interchange(ch, {})
local redot_manifest = redot_bundle and file_by_path(redot_bundle.files, 'manifest.json') or nil
check(
    'redot interchange: redot format tag, tscn sketch, gd stub present',
    redot_manifest ~= nil
        and redot_manifest:find('"format":"diver-character-redot"', 1, true) ~= nil
        and redot_bundle ~= nil
        and file_by_path(redot_bundle.files, 'hero.tscn') ~= nil
        and file_by_path(redot_bundle.files, 'import_hero.gd') ~= nil,
    false,
    redot_err
)

-- Kit names may contain quotes/newlines (only NUL is rejected), so the
-- .tscn sketch must escape part names instead of interpolating them raw.
local hostile_part = character.new_character('hostile')
character.add_part(hostile_part, {
    name = 'a"b\nc',
    anchor = { x = 0, y = 0 },
    zindex = 0,
    sprite = 'a.png',
    tags = {},
})
character.add_timeline(hostile_part, 'idle', { loop = true, fps = 1, duration_sec = 1 })
local godot_hostile = godot_character.build_interchange(hostile_part, {})
local redot_hostile = redot_character.build_interchange(hostile_part, {})
local godot_htscn = godot_hostile and file_by_path(godot_hostile.files, 'hostile.tscn') or ''
local redot_htscn = redot_hostile and file_by_path(redot_hostile.files, 'hostile.tscn') or ''
check(
    'godot/redot tscn: hostile part names are escaped, no attribute breakout',
    godot_htscn:find('[node name="a\\"b\\nc" type="Sprite2D" parent="."]', 1, true) ~= nil
        and redot_htscn:find('[node name="a\\"b\\nc" type="Sprite2D" parent="."]', 1, true) ~= nil
        and godot_htscn:find('name="a"b', 1, true) == nil
        and redot_htscn:find('name="a"b', 1, true) == nil,
    false
)

-- ============ validation: unity (4) ============

local unity_cap = unity_character.capabilities()
check(
    'unity capabilities: 2D yes, 3D via-interchange',
    unity_cap.dims_2d == true and unity_cap.dims_3d == 'via-interchange',
    false
)
check(
    'unity capabilities: honest no-runtime-bridge note',
    notes_contain(unity_cap, 'No runtime bridge') and notes_contain(unity_cap, 'cannot be validated in this sandbox'),
    false
)

local unity_bundle, unity_err = unity_character.build_interchange(ch, {})
local unity_manifest = unity_bundle and file_by_path(unity_bundle.files, 'manifest.json') or nil
local unity_cs = unity_bundle and file_by_path(unity_bundle.files, 'CharacterImport_hero.cs') or nil
check(
    'unity interchange: manifest + C# stub with menu item',
    unity_manifest ~= nil
        and unity_manifest:find('"format":"diver-character-unity"', 1, true) ~= nil
        and unity_manifest:find('"pos":[50,25]', 1, true) ~= nil
        and unity_cs ~= nil
        and unity_cs:find('MenuItem', 1, true) ~= nil
        and unity_cs:find('Diver/Import Character', 1, true) ~= nil,
    false,
    unity_err
)
local unity_has_starting = unity_cs ~= nil and unity_cs:find('starting', 1, true) ~= nil
local unity_has_bridge = unity_cs ~= nil and unity_cs:find('No runtime bridge', 1, true) ~= nil
check('unity stub: honest starting-point disclaimer', unity_has_starting and unity_has_bridge, false)

-- ============ validation: unreal (4) ============

local unreal_cap = unreal_character.capabilities()
check(
    'unreal capabilities: 2D yes, 3D via-interchange',
    unreal_cap.dims_2d == true and unreal_cap.dims_3d == 'via-interchange',
    false
)
check(
    'unreal capabilities: honest no-runtime-bridge note',
    notes_contain(unreal_cap, 'No runtime bridge') and notes_contain(unreal_cap, 'cannot be validated in this sandbox'),
    false
)

local unreal_bundle, unreal_err = unreal_character.build_interchange(ch, {})
local unreal_manifest = unreal_bundle and file_by_path(unreal_bundle.files, 'manifest.json') or nil
local unreal_py = unreal_bundle and file_by_path(unreal_bundle.files, 'import_hero.py') or nil
check(
    'unreal interchange: manifest + Python editor stub',
    unreal_manifest ~= nil
        and unreal_manifest:find('"format":"diver-character-unreal"', 1, true) ~= nil
        and unreal_manifest:find('"pos":[50,25]', 1, true) ~= nil
        and unreal_py ~= nil
        and unreal_py:find('unreal.', 1, true) ~= nil
        and unreal_py:find('import_character', 1, true) ~= nil,
    false,
    unreal_err
)
check(
    'unreal stub: honest starting-point disclaimer',
    unreal_py ~= nil
        and unreal_py:find('starting', 1, true) ~= nil
        and unreal_py:find('no runtime bridge', 1, true) ~= nil,
    false
)

-- ============ validation: aseprite (3) ============

local aseprite_cap = aseprite_character.capabilities()
check('aseprite capabilities: 2D yes, 3D no', aseprite_cap.dims_2d == true and aseprite_cap.dims_3d == false, false)

local assembly, assembly_err = aseprite_character.build_assembly_script(ch)
check(
    'aseprite assembly: tags per timeline with ping-pong direction',
    assembly ~= nil
        and assembly:find('newTag', 1, true) ~= nil
        and assembly:find('"idle"', 1, true) ~= nil
        and assembly:find('"walk"', 1, true) ~= nil
        and assembly:find('PING_PONG', 1, true) ~= nil,
    false,
    assembly_err
)

local sheet_argv, sheet_argv_err =
    aseprite_character.build_sheet_argv('/usr/bin/aseprite', 'hero.aseprite', 'hero.png', 'hero.json', {})
local argv_has = function(flag)
    for _, a in ipairs(sheet_argv or {}) do
        if a == flag then
            return true
        end
    end
    return false
end
check(
    'aseprite sheet argv: --sheet with --data json-array',
    sheet_argv ~= nil
        and argv_has('-b')
        and argv_has('--sheet')
        and argv_has('--data')
        and argv_has('--format')
        and argv_has('json-array'),
    false,
    sheet_argv_err
)

-- ============ adversarial ============

-- love2d adversarial (4)
local bad1, bad1_err = love2d_character.build_project(as_any(nil), {})
check('love2d rejects nil character before generation', bad1 == nil and bad1_err ~= nil, true)

local hostile_version = {
    version = 99,
    name = 'x',
    parts = {},
    palettes = {},
    timelines = {},
    skeleton = {
        joints = {},
        root = '',
    },
}
local bad2, bad2_err = love2d_character.build_project(hostile_version, {})
check('love2d rejects wrong schema version', bad2 == nil and (bad2_err or ''):find('invalid', 1, true) ~= nil, true)

local evil_sprite = character.new_character('evil')
character.add_part(evil_sprite, {
    name = 'p',
    anchor = { x = 0, y = 0 },
    zindex = 0,
    sprite = '../../evil.png',
    tags = {},
})
character.add_timeline(evil_sprite, 'idle', { loop = true, fps = 1, duration_sec = 1 })
local bad3, bad3_err = love2d_character.build_project(evil_sprite, {})
check(
    'love2d rejects path-traversal sprite',
    bad3 == nil and (bad3_err or ''):find('unsafe sprite', 1, true) ~= nil,
    true
)

local newline_name = character.new_character('plain')
character.add_part(newline_name, { name = 'p', anchor = { x = 0, y = 0 }, zindex = 0, tags = {} })
character.add_timeline(newline_name, 'idle', { loop = true, fps = 1, duration_sec = 1 })
local project4 = love2d_character.build_project(newline_name, { name = 'x\ny' })
local conf4 = project4 and file_by_path(project4.files, 'conf.lua') or ''
check(
    'love2d sanitizes control chars out of the project title',
    project4 ~= nil and conf4:find("t.window.title = 'xy'", 1, true) ~= nil,
    true
)

-- blender adversarial (4)
local bad5, bad5_err = blender_character.build_spec({}, 'pose2d', {})
check('blender rejects empty table before spec build', bad5 == nil and bad5_err ~= nil, true)

local bad6, bad6_err = blender_character.build_argv('a\0b', '/tmp/x.py', nil)
check('blender build_argv rejects NUL in binary path', bad6 == nil and bad6_err ~= nil, true)

local bad7, bad7_err = blender_character.build_blend(ch, 'pose2d', '/tmp/x.blend', { bin = '/nonexistent/blender-xyz' })
local bad7b, bad7b_err = blender_character.export_sprite_sheet(ch, '/tmp/x-sheet', { bin = '/nonexistent/blender-xyz' })
local bad7c, bad7c_err = blender_character.export_sprite_sheet(ch, '', {})
check(
    'blender build_blend and export_sprite_sheet fail closed (missing binary, bad out_dir)',
    bad7 == nil
        and (bad7_err or ''):find('not found', 1, true) ~= nil
        and bad7b == nil
        and (bad7b_err or ''):find('not found', 1, true) ~= nil
        and bad7c == nil
        and (bad7c_err or ''):find('out_dir', 1, true) ~= nil,
    true
)

local bad8a, bad8a_err = blender_character.export_interchange('/tmp/x.blend', '/tmp/x.glb', 'obj', {})
local bad8b, bad8b_err =
    blender_character.export_interchange('/tmp/x.blend', '/tmp/x.glb', 'glb', { bin = '/nonexistent/blender-xyz' })
check(
    'blender export_interchange rejects bad kind and missing binary',
    bad8a == nil
        and (bad8a_err or ''):find('glb', 1, true) ~= nil
        and bad8b == nil
        and (bad8b_err or ''):find('not found', 1, true) ~= nil,
    true
)

-- godot adversarial (4)
local bad9, bad9_err = godot_character.build_interchange(as_any('not a table'), {})
check('godot rejects non-table character', bad9 == nil and bad9_err ~= nil, true)

local bad10, bad10_err = godot_character.validate_project('/tmp', {})
check(
    'godot validate_project rejects dirs without project.godot',
    bad10 == nil and (bad10_err or ''):find('project.godot', 1, true) ~= nil,
    true
)

local mock_dir = os.tmpname()
os.remove(mock_dir)
os.execute('mkdir -p ' .. mock_dir)
local godot_proj = io.open(mock_dir .. '/project.godot', 'w')
if godot_proj ~= nil then
    godot_proj:write('[application]\n')
    godot_proj:close()
end
local bad11, bad11_err = godot_character.validate_project(mock_dir, { bin = '/nonexistent/godot-xyz' })
local bad11b, bad11b_err = godot_character.export_sprite_sheet(ch, '/tmp/x-sheet', { bin = '/nonexistent/blender-xyz' })
check(
    'godot validate_project and export_sprite_sheet fail closed on missing binary',
    bad11 == nil
        and (bad11_err or ''):find('not found', 1, true) ~= nil
        and (bad11_err or ''):find('unavailable', 1, true) ~= nil
        and bad11b == nil
        and (bad11b_err or ''):find('not found', 1, true) ~= nil,
    true
)
os.execute('rm -rf ' .. mock_dir)

local bad12 = godot_character.build_interchange(ch, { name = '../../evil' })
local tscn_path = bad12 and bad12.files[2].path or ''
check('godot sanitizes path-traversal character names', bad12 ~= nil and tscn_path:find('/', 1, true) == nil, true)

-- redot adversarial (3)
local ch_table = character.to_table(ch)
ch_table.timelines.broken = {
    loop = true,
    fps = 1,
    duration_sec = 1,
    tracks = { ghost = { { t = 0 } } },
}
local bad13, bad13_err = redot_character.build_interchange(ch_table, {})
check(
    'redot rejects timeline referencing an undeclared part',
    bad13 == nil and (bad13_err or ''):find('invalid', 1, true) ~= nil,
    true
)

local redot_dir = os.tmpname()
os.remove(redot_dir)
os.execute('mkdir -p ' .. redot_dir)
local redot_proj = io.open(redot_dir .. '/project.godot', 'w')
if redot_proj ~= nil then
    redot_proj:write('[application]\n')
    redot_proj:close()
end
local bad14, bad14_err = redot_character.validate_project(redot_dir, { bin = '/nonexistent/redot-xyz' })
local bad14b, bad14b_err = redot_character.export_sprite_sheet(ch, '/tmp/x-sheet', { bin = '/nonexistent/blender-xyz' })
check(
    'redot validate_project and export_sprite_sheet fail closed on missing binary',
    bad14 == nil
        and (bad14_err or ''):find('Redot', 1, true) ~= nil
        and (bad14_err or ''):find('not found', 1, true) ~= nil
        and bad14b == nil
        and (bad14b_err or ''):find('not found', 1, true) ~= nil,
    true
)
os.execute('rm -rf ' .. redot_dir)

local abs_sprite = character.new_character('abs')
character.add_part(abs_sprite, {
    name = 'p',
    anchor = { x = 0, y = 0 },
    zindex = 0,
    sprite = '/abs/path.png',
    tags = {},
})
character.add_timeline(abs_sprite, 'idle', { loop = true, fps = 1, duration_sec = 1 })
local bad15, bad15_err = redot_character.build_interchange(abs_sprite, {})
check(
    'redot rejects absolute sprite paths',
    bad15 == nil and (bad15_err or ''):find('unsafe sprite', 1, true) ~= nil,
    true
)

-- unity adversarial (4)
local bad16, bad16_err = unity_character.build_interchange(as_any(nil), {})
check('unity rejects nil character', bad16 == nil and bad16_err ~= nil, true)

local bad17, bad17_err = unity_character.export_model(ch, '/tmp/x.fbx', 'obj', {})
check(
    'unity export_model rejects unknown kind',
    bad17 == nil and (bad17_err or ''):find("'fbx' or 'glb'", 1, true) ~= nil,
    true
)

local bad18, bad18_err = unity_character.export_model(ch, '/tmp/x.fbx', 'fbx', {})
local bad18b, bad18b_err = unity_character.export_sprite_sheet(ch, '/tmp/x-sheet', { bin = '/nonexistent/blender-xyz' })
check(
    'unity export_model and export_sprite_sheet fail closed without Neovim/blender',
    bad18 == nil
        and bad18_err ~= nil
        and ((bad18_err:find('Neovim', 1, true) ~= nil) or (bad18_err:find('blender', 1, true) ~= nil))
        and bad18b == nil
        and (bad18b_err or ''):find('blender', 1, true) ~= nil,
    true,
    bad18_err
)

local bad19 = unity_character.build_interchange(ch, { name = 'a/b' })
local cs_path = bad19 and bad19.files[2].path or ''
check('unity sanitizes slashes out of file names', bad19 ~= nil and cs_path:find('/', 1, true) == nil, true)

-- unreal adversarial (4)
local bad20, bad20_err = unreal_character.build_interchange({}, {})
check('unreal rejects empty table character', bad20 == nil and bad20_err ~= nil, true)

local bad21, bad21_err = unreal_character.export_model(ch, '/tmp/x.fbx', 'dae', {})
check('unreal export_model rejects unknown kind', bad21 == nil and bad21_err ~= nil, true)

local bad22, bad22_err = unreal_character.export_model(ch, '/tmp/x.fbx', 'glb', {})
local bad22b, bad22b_err =
    unreal_character.export_sprite_sheet(ch, '/tmp/x-sheet', { bin = '/nonexistent/blender-xyz' })
check(
    'unreal export_model and export_sprite_sheet fail closed without Neovim/blender',
    bad22 == nil and bad22_err ~= nil and bad22b == nil and (bad22b_err or ''):find('blender', 1, true) ~= nil,
    true,
    bad22_err
)

local bad23, bad23_err = unreal_character.build_interchange(hostile_version, {})
check('unreal rejects wrong schema version', bad23 == nil and (bad23_err or ''):find('invalid', 1, true) ~= nil, true)

-- aseprite adversarial (5)
local bad24, bad24_err = aseprite_character.build_assembly_script(as_any(nil))
check('aseprite rejects nil character', bad24 == nil and bad24_err ~= nil, true)

local found_bin = aseprite_character.find_binary('/nonexistent/aseprite-xyz')
check('aseprite find_binary returns nil for missing override', found_bin == nil, true)

local bad26, bad26_err = aseprite_character.export_sheet(ch, '/tmp/aseprite-out', { bin = '/nonexistent/aseprite-xyz' })
check(
    'aseprite export_sheet fails closed on missing binary',
    bad26 == nil and (bad26_err or ''):find('not found', 1, true) ~= nil,
    true
)

local no_sprite = character.new_character('nosprite')
character.add_part(no_sprite, { name = 'p', anchor = { x = 0, y = 0 }, zindex = 0, tags = {} })
character.add_timeline(no_sprite, 'idle', { loop = true, fps = 1, duration_sec = 1 })
local bad27, bad27_err = aseprite_character.build_assembly_script(no_sprite)
check(
    'aseprite assembly requires a sprite per part',
    bad27 == nil and (bad27_err or ''):find('needs a sprite', 1, true) ~= nil,
    true
)

local bad28, bad28_err =
    aseprite_character.build_sheet_argv('/usr/bin/aseprite', 'x.aseprite', 'x.png', 'x.json', { sheet_type = 'bogus' })
check('aseprite sheet argv rejects bad sheet_type', bad28 == nil and bad28_err ~= nil, true)

print(
    string.format(
        '\ncharacter_engines: %d passed, %d failed (validation %d/%d, adversarial %d/%d)',
        pass_count,
        fail_count,
        pass_count - adversarial_pass,
        (pass_count - adversarial_pass) + (fail_count - adversarial_fail),
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)
os.exit(fail_count > 0 and 1 or 0)
