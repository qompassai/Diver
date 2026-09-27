-- Headless test for games/shared character kit.
-- Runs under plain Lua (the module has no vim.* dependency at require
-- time) and inside headless Neovim with the full config. Exercises the
-- builder, validator, serialization round-trip, and pose sampler.
--
-- Split: 24 validation checks, 24 adversarial checks.
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

local function has_err(errs, sub)
    for _, e in ipairs(errs) do
        if e:find(sub, 1, true) then
            return true
        end
    end
    return false
end

local function deep_equal(a, b)
    if a == b then
        return true
    end
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return false
    end
    for k, v in pairs(a) do
        if not deep_equal(v, b[k]) then
            return false
        end
    end
    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end
    return true
end

local function reversed(arr)
    local out = {}
    for i = #arr, 1, -1 do
        out[#out + 1] = arr[i]
    end
    return out
end

local character = require('games.shared.character')

-- ============ validation: builder happy paths ============
local ch = character.new_character('hero')
check(
    'new_character sets name/version/empties',
    ch.name == 'hero' and ch.version == 1 and #ch.parts == 0 and ch.skeleton.root == '' and ch.joints_3d == nil
)

character.add_part(ch, { name = 'torso', anchor = { x = 16, y = 32 }, zindex = 0 })
check(
    'add_part stores anchor/zindex, defaults tags and sprite',
    ch.parts[1].anchor.x == 16
        and ch.parts[1].anchor.y == 32
        and ch.parts[1].zindex == 0
        and #ch.parts[1].tags == 0
        and ch.parts[1].sprite == nil
)

character.add_part(ch, {
    name = 'head',
    anchor = { x = 8, y = 8 },
    zindex = 10,
    sprite = 'sprites/head.png',
    tags = { 'helmet-slot' },
})
check(
    'add_part keeps sprite and tags',
    ch.parts[2].sprite == 'sprites/head.png' and ch.parts[2].tags[1] == 'helmet-slot'
)

character.add_palette(ch, {
    name = 'day',
    colors = { '#ff0000', '#00ff00' },
    map = { ['#ff0000'] = '#0000ff' },
})
check(
    'add_palette stores colors and recolor map',
    ch.palettes.day.colors[2] == '#00ff00' and ch.palettes.day.map['#ff0000'] == '#0000ff'
)

character.add_timeline(ch, 'walk', { loop = 'pingpong', fps = 12, duration_sec = 2 })
check(
    'add_timeline stores loop/fps/duration',
    ch.timelines.walk.loop == 'pingpong' and ch.timelines.walk.fps == 12 and ch.timelines.walk.duration_sec == 2
)

character.add_joint(ch, {
    name = 'hips',
    pivot = { x = 0, y = 0 },
    rot_min_deg = -45,
    rot_max_deg = 45,
    length_px = 24,
})
check('add_joint makes the first joint the root', ch.skeleton.root == 'hips')

character.add_joint(ch, {
    name = 'spine',
    parent = 'hips',
    pivot = { x = 0, y = 24 },
    rot_min_deg = -30,
    rot_max_deg = 30,
    length_px = 20,
})
check('add_joint stores parent link', ch.skeleton.joints.spine.parent == 'hips')

character.add_joint_3d(ch, {
    name = 'hips3',
    limits = { pitch = { -30, 30 }, yaw = { -45, 45 }, roll = { -10, 10 } },
})
check('add_joint_3d stores axis limits', ch.joints_3d.hips3.limits.pitch[1] == -30)

character.set_keyframe(ch, 'walk', 'torso', { t = 0, pos = { x = 0, y = 0 }, rot_deg = 0 })
character.set_keyframe(ch, 'walk', 'torso', { t = 2, pos = { x = 100, y = 50 }, rot_deg = 90 })
check('set_keyframe appends in order', #ch.timelines.walk.tracks.torso == 2)

-- More timelines/parts for the sampling checks below.
character.add_timeline(ch, 'idle', { loop = false, fps = 12, duration_sec = 2 })
character.set_keyframe(ch, 'idle', 'torso', { t = 0, pos = { x = 0, y = 0 }, rot_deg = 0 })
character.set_keyframe(ch, 'idle', 'torso', { t = 2, pos = { x = 100, y = 50 }, rot_deg = 90 })
character.add_timeline(ch, 'run', { loop = true, fps = 12, duration_sec = 2 })
character.set_keyframe(ch, 'run', 'torso', { t = 0, pos = { x = 0, y = 0 }, rot_deg = 0 })
character.set_keyframe(ch, 'run', 'torso', { t = 2, pos = { x = 100, y = 50 }, rot_deg = 90 })
character.add_timeline(ch, 'blink', { loop = false, fps = 12, duration_sec = 2 })
character.set_keyframe(ch, 'blink', 'head', { t = 0, visible = false })
character.set_keyframe(ch, 'blink', 'head', { t = 2, visible = true })
character.add_timeline(ch, 'late', { loop = false, fps = 12, duration_sec = 2 })
character.set_keyframe(ch, 'late', 'torso', { t = 1, pos = { x = 10, y = 10 } })
character.set_keyframe(ch, 'late', 'torso', { t = 2, pos = { x = 20, y = 20 } })
character.add_part(ch, { name = 'hat', anchor = { x = 0, y = 0 }, zindex = 20 })

-- Builder copies caller tables: mutating the spec afterwards is safe.
local ext_anchor = { x = 5, y = 6 }
character.add_part(ch, { name = 'shield', anchor = ext_anchor, zindex = 5 })
ext_anchor.x = 500
check('add_part copies the anchor table', ch.parts[#ch.parts].anchor.x == 5)

local ext_kf = { t = 0, pos = { x = 1, y = 1 } }
character.set_keyframe(ch, 'idle', 'shield', ext_kf)
ext_kf.pos.x = 500
check('set_keyframe copies the keyframe', ch.timelines.idle.tracks.shield[1].pos.x == 1)

local ok, verrs = character.validate_character(ch)
check('validate_character accepts a well-formed character', ok and #verrs == 0, false, verrs[1])

-- ============ validation: serialization ============
local snap = character.to_table(ch)
local back, berr = character.from_table(snap)
check(
    'to_table/from_table carry the version and rebuild the character',
    snap.version == 1 and back ~= nil and berr == nil,
    false,
    tostring(berr)
)
check('round-trip deep-equals the original', back ~= nil and deep_equal(back, ch))

snap.parts[1].anchor.x = 999
check('to_table output does not alias the character', ch.parts[1].anchor.x == 16)

-- ============ validation: pose sampling ============
local pose = character.sample_pose(ch, 'idle', 1)
check(
    'sample_pose interpolates pos (hand-computed)',
    pose ~= nil and math.abs(pose.torso.pos.x - 50) < 1e-9 and math.abs(pose.torso.pos.y - 25) < 1e-9
)
check('sample_pose interpolates rot (hand-computed)', pose ~= nil and math.abs(pose.torso.rot_deg - 45) < 1e-9)
check(
    'sample_pose defaults missing scale to {1,1}',
    pose ~= nil and pose.torso.scale.x == 1 and pose.torso.scale.y == 1
)

local exact = character.sample_pose(ch, 'idle', 2)
check(
    'sample_pose at an exact keyframe time returns that pose',
    exact ~= nil and exact.torso.pos.x == 100 and exact.torso.rot_deg == 90
)

local early = character.sample_pose(ch, 'late', 0)
check(
    'sample_pose before the first keyframe holds the first pose',
    early ~= nil and early.torso.pos.x == 10 and early.torso.pos.y == 10
)

local hat_pose = character.sample_pose(ch, 'idle', 1)
check(
    'untracked part gets the default pose',
    hat_pose ~= nil
        and hat_pose.hat.pos.x == 0
        and hat_pose.hat.rot_deg == 0
        and hat_pose.hat.scale.x == 1
        and hat_pose.hat.visible == true
)

local pv_off = character.sample_pose(ch, 'blink', 0.5)
local pv_on = character.sample_pose(ch, 'blink', 2.0)
check(
    'visible snaps at keyframe times (no blending)',
    pv_off ~= nil and pv_off.head.visible == false and pv_on ~= nil and pv_on.head.visible == true
)

local no_pose, no_err = character.sample_pose(ch, 'nope', 0)
check('sample_pose on an unknown timeline returns nil, err', no_pose == nil and no_err ~= nil)

-- Hand-written table (not builder-made), maps inserted in shuffled
-- order: from_table must not care about key order, and must place the
-- child joint after its parent regardless of map order.
local raw = {
    version = 1,
    name = 'raw',
    parts = {
        { name = 'b', anchor = { x = 1, y = 1 }, zindex = 1, tags = {} },
        { name = 'a', anchor = { x = 2, y = 2 }, zindex = 0, tags = { 't' } },
    },
    palettes = {
        zed = { colors = { '#112233' }, map = {} },
        abc = { colors = { '#aabbcc', '#ddeeff' }, map = { ['#aabbcc'] = '#000000' } },
    },
    timelines = {},
    skeleton = {
        joints = {
            j2 = {
                parent = 'j1',
                pivot = { x = 0, y = 0 },
                rot_min_deg = -10,
                rot_max_deg = 10,
                length_px = 5,
            },
            j1 = {
                parent = nil,
                pivot = { x = 0, y = 0 },
                rot_min_deg = 0,
                rot_max_deg = 0,
                length_px = 5,
            },
        },
        root = 'j1',
    },
}
local raw_ch, raw_err = character.from_table(raw)
local raw2 = {
    version = 1,
    name = 'raw',
    parts = raw.parts,
    palettes = {},
    timelines = {},
    skeleton = { joints = {}, root = 'j1' },
}
for _, k in ipairs(reversed({ 'zed', 'abc' })) do
    raw2.palettes[k] = raw.palettes[k]
end
for _, k in ipairs(reversed({ 'j2', 'j1' })) do
    raw2.skeleton.joints[k] = raw.skeleton.joints[k]
end
local raw2_ch, raw2_err = character.from_table(raw2)
check(
    'from_table accepts hand-written tables regardless of map order',
    raw_ch ~= nil and raw2_ch ~= nil and raw_ch.skeleton.joints.j2.parent == 'j1' and deep_equal(raw_ch, raw2_ch),
    false,
    tostring(raw_err or raw2_err)
)

-- ============ adversarial ============
local dup_ok = pcall(character.add_part, ch, { name = 'torso', anchor = { x = 0, y = 0 }, zindex = 1 })
check('add_part rejects a duplicate part name', dup_ok == false, true)

local bad_z = pcall(character.add_part, ch, { name = 'badz', anchor = { x = 0, y = 0 }, zindex = 1.5 })
local bad_a = pcall(character.add_part, ch, { name = 'bada', anchor = { x = 99999, y = 0 }, zindex = 0 })
check('add_part rejects non-integer zindex and out-of-range anchor', bad_z == false and bad_a == false, true)

local bad_n = pcall(character.add_part, ch, { name = '', anchor = { x = 0, y = 0 }, zindex = 0 })
check('add_part rejects an empty part name', bad_n == false, true)

local bad_h1 = pcall(character.add_palette, ch, { name = 'h1', colors = { '#ff00' } })
local bad_h2 = pcall(character.add_palette, ch, { name = 'h2', colors = { 'red' } })
check('add_palette rejects malformed hex', bad_h1 == false and bad_h2 == false, true)

local many_colors = {}
for i = 1, 257 do
    many_colors[i] = '#ffffff'
end
local many_ok = pcall(character.add_palette, ch, { name = 'many', colors = many_colors })
check('add_palette rejects 257 colors (bound 256)', many_ok == false, true)

local bad_l = pcall(character.add_timeline, ch, 'badl', { loop = 'bounce', fps = 12, duration_sec = 2 })
local bad_f = pcall(character.add_timeline, ch, 'badf', { loop = false, fps = 0, duration_sec = 2 })
local bad_d = pcall(character.add_timeline, ch, 'badd', { loop = false, fps = 12, duration_sec = -1 })
check('add_timeline rejects bad loop/fps/duration', bad_l == false and bad_f == false and bad_d == false, true)

local dec_ok = pcall(character.set_keyframe, ch, 'walk', 'torso', { t = 1 })
check('set_keyframe rejects decreasing time', dec_ok == false, true)

local nan_ok = pcall(character.set_keyframe, ch, 'walk', 'torso', { t = 0 / 0 })
check('set_keyframe rejects NaN time', nan_ok == false, true)

local unk_p = pcall(character.set_keyframe, ch, 'walk', 'ghost', { t = 0 })
local unk_a = pcall(character.set_keyframe, ch, 'ghost', 'torso', { t = 0 })
check('set_keyframe rejects unknown part and timeline', unk_p == false and unk_a == false, true)

local big = character.new_character('big')
character.add_part(big, { name = 'p', anchor = { x = 0, y = 0 }, zindex = 0 })
character.add_timeline(big, 'a', { loop = false, fps = 30, duration_sec = 3600 })
for i = 1, 4096 do
    character.set_keyframe(big, 'a', 'p', { t = i * 0.5 })
end
local over_ok = pcall(character.set_keyframe, big, 'a', 'p', { t = 2048.5 })
check(
    'set_keyframe rejects the 4097th keyframe (bound 4096)',
    over_ok == false and #big.timelines.a.tracks.p == 4096,
    true
)

local orphan_ok = pcall(character.add_joint, ch, {
    name = 'orphan',
    parent = 'nobody',
    pivot = { x = 0, y = 0 },
    rot_min_deg = 0,
    rot_max_deg = 0,
    length_px = 1,
})
check('add_joint rejects an unknown parent', orphan_ok == false, true)

local flip_ok = pcall(character.add_joint, ch, {
    name = 'flip',
    pivot = { x = 0, y = 0 },
    rot_min_deg = 10,
    rot_max_deg = -10,
    length_px = 1,
})
check('add_joint rejects rot_min_deg > rot_max_deg', flip_ok == false, true)

local cyc = character.new_character('cyc')
character.add_joint(cyc, {
    name = 'a',
    pivot = { x = 0, y = 0 },
    rot_min_deg = 0,
    rot_max_deg = 0,
    length_px = 10,
})
character.add_joint(cyc, {
    name = 'b',
    parent = 'a',
    pivot = { x = 0, y = 0 },
    rot_min_deg = 0,
    rot_max_deg = 0,
    length_px = 10,
})
cyc.skeleton.joints.a.parent = 'b' -- hostile poke: a <-> b cycle
local cyc_ok, cyc_errs = character.validate_character(cyc)
check('validate_character catches a joint parent cycle', cyc_ok == false and has_err(cyc_errs, 'cycle'), true)

local bad_track = {
    version = 1,
    name = 'x',
    parts = {},
    palettes = {},
    timelines = {
        a = { loop = false, fps = 30, duration_sec = 10, tracks = { ghost = { { t = 0 } } } },
    },
    skeleton = { joints = {}, root = '' },
}
local bt_ch, bt_err = character.from_table(bad_track)
check(
    'from_table rejects a track for an undeclared part',
    bt_ch == nil and bt_err ~= nil and bt_err:find('undeclared', 1, true) ~= nil,
    true,
    tostring(bt_err)
)

local unsorted = {
    version = 1,
    name = 'x',
    parts = { { name = 'p', anchor = { x = 0, y = 0 }, zindex = 0, tags = {} } },
    palettes = {},
    timelines = {
        a = { loop = false, fps = 30, duration_sec = 10, tracks = { p = { { t = 1 }, { t = 0.5 } } } },
    },
    skeleton = { joints = {}, root = '' },
}
local us_ch, us_err = character.from_table(unsorted)
check(
    'from_table rejects unsorted keyframes',
    us_ch == nil and us_err ~= nil and us_err:find('out of order', 1, true) ~= nil,
    true,
    tostring(us_err)
)

local neg_t = {
    version = 1,
    name = 'x',
    parts = { { name = 'p', anchor = { x = 0, y = 0 }, zindex = 0, tags = {} } },
    palettes = {},
    timelines = {
        a = { loop = false, fps = 30, duration_sec = 10, tracks = { p = { { t = -1 } } } },
    },
    skeleton = { joints = {}, root = '' },
}
local nt_ch, nt_err = character.from_table(neg_t)
check(
    'from_table rejects a negative keyframe time',
    nt_ch == nil and nt_err ~= nil and nt_err:find('>= 0', 1, true) ~= nil,
    true,
    tostring(nt_err)
)

local bad_hex = {
    version = 1,
    name = 'x',
    parts = {},
    palettes = { day = { colors = { 'nothex' }, map = {} } },
    timelines = {},
    skeleton = { joints = {}, root = '' },
}
local hx_ch, hx_err = character.from_table(bad_hex)
check(
    'from_table rejects a malformed palette hex',
    hx_ch == nil and hx_err ~= nil and hx_err:find('hex', 1, true) ~= nil,
    true,
    tostring(hx_err)
)

local bad_ver = {
    version = 2,
    name = 'x',
    parts = {},
    palettes = {},
    timelines = {},
    skeleton = { joints = {}, root = '' },
}
local bv_ch, bv_err = character.from_table(bad_ver)
local nt2_ch, nt2_err = character.from_table('not a table')
check(
    'from_table rejects unknown versions and non-tables',
    bv_ch == nil and bv_err ~= nil and bv_err:find('version', 1, true) ~= nil and nt2_ch == nil and nt2_err ~= nil,
    true,
    tostring(bv_err)
)

local hostile_track = {}
for i = 1, 100001 do
    hostile_track[i] = { t = i * 0.01 }
end
local hostile = {
    version = 1,
    name = 'hostile',
    parts = { { name = 'p', anchor = { x = 0, y = 0 }, zindex = 0, tags = {} } },
    palettes = {},
    timelines = {
        a = { loop = false, fps = 30, duration_sec = 3600, tracks = { p = hostile_track } },
    },
    skeleton = { joints = {}, root = '' },
}
local h_ch, h_err = character.from_table(hostile)
check(
    'from_table rejects a 100001-keyframe track at the bound',
    h_ch == nil and h_err ~= nil and h_err:find('4096', 1, true) ~= nil,
    true,
    tostring(h_err)
)

local nan_pose, nan_err = character.sample_pose(ch, 'idle', 0 / 0)
check('sample_pose rejects NaN t', nan_pose == nil and nan_err ~= nil, true)

local clamped = character.sample_pose(ch, 'idle', 99)
check(
    'sample_pose beyond duration clamps when loop=false',
    clamped ~= nil and clamped.torso.pos.x == 100 and clamped.torso.rot_deg == 90,
    true
)

local wrapped = character.sample_pose(ch, 'run', 3)
check(
    'sample_pose beyond duration wraps when loop=true',
    wrapped ~= nil and math.abs(wrapped.torso.pos.x - 50) < 1e-9 and math.abs(wrapped.torso.rot_deg - 45) < 1e-9,
    true
)

local pong = character.sample_pose(ch, 'walk', 3)
local pong2 = character.sample_pose(ch, 'walk', 2.5)
check(
    "sample_pose beyond duration mirrors when loop='pingpong'",
    pong ~= nil
        and math.abs(pong.torso.pos.x - 50) < 1e-9
        and pong2 ~= nil
        and math.abs(pong2.torso.pos.x - 75) < 1e-9
        and math.abs(pong2.torso.pos.y - 37.5) < 1e-9,
    true
)

local neg_pose = character.sample_pose(ch, 'idle', -5)
check(
    'sample_pose clamps negative t to the start',
    neg_pose ~= nil and neg_pose.torso.pos.x == 0 and neg_pose.torso.rot_deg == 0,
    true
)

print(
    string.format(
        '\ncharacter_kit: %d passed, %d failed (adversarial %d/%d)',
        pass_count,
        fail_count,
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)
os.exit(fail_count > 0 and 1 or 0)
