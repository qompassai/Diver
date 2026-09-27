-- Headless test for the six LÖVE2D engine adapters
-- (lua/games/love2d/adapters/{aseprite,blender,godot,redot,unity,unreal}.lua).
-- Runs under headless Neovim nightly with the full diver config:
--   nvim --headless -i NONE -c "luafile tests/lua/love2d_adapters.lua" -c "quit!"
-- from the repo root. The contract gate (validate_adapter/1) is
-- exercised for real; where an adapter cannot be validated against a
-- live engine here (unity/unreal editor-side), the tests assert the
-- documented limits and fail-closed behavior instead of faking
-- success.
--
-- Split: 18 validation checks, 18 adversarial checks.
local contract = require('games.love2d.adapters')
local libs = require('games.love2d.libs')
local blender_config = require('games.blender.config')
local aseprite = require('games.love2d.adapters.aseprite')
local blender = require('games.love2d.adapters.blender')
local godot = require('games.love2d.adapters.godot')
local redot = require('games.love2d.adapters.redot')
local unity = require('games.love2d.adapters.unity')
local unreal = require('games.love2d.adapters.unreal')

local pass_count, fail_count = 0, 0
local adversarial_pass, adversarial_fail = 0, 0

local function check(name, cond, adversarial)
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
        print('FAIL: ' .. name)
    end
end

local order = { 'aseprite', 'blender', 'godot', 'redot', 'unity', 'unreal' }
local adapters = {
    aseprite = aseprite,
    blender = blender,
    godot = godot,
    redot = redot,
    unity = unity,
    unreal = unreal,
}

local function limits_mention(mod, needle)
    for _, limit in ipairs(mod.asset_interchange.limits) do
        if limit:find(needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function good_manifest(engine_key)
    return {
        engine = engine_key,
        assets = {
            { path = 'assets/hero.png', kind = 'png' },
            { path = 'assets/jump.ogg', kind = 'ogg' },
        },
    }
end

-- ============ validation ============
for _, key in ipairs(order) do
    local mod = adapters[key]
    local ok, errs = contract.validate_adapter(mod)
    check('validate_adapter accepts the ' .. key .. ' adapter', ok and #errs == 0, false)
end

check('unity declares runtime_interop=false', unity.asset_interchange.runtime_interop == false, false)
check('unreal declares runtime_interop=false', unreal.asset_interchange.runtime_interop == false, false)
check('godot declares runtime_interop=false', godot.asset_interchange.runtime_interop == false, false)
check('redot declares runtime_interop=false', redot.asset_interchange.runtime_interop == false, false)

local limits_ok = true
for _, key in ipairs(order) do
    if #adapters[key].asset_interchange.limits < 1 then
        limits_ok = false
    end
end
check('every adapter names at least one limit (honesty rule)', limits_ok, false)

local libraries_ok = true
for _, key in ipairs(order) do
    for _, lib_key in ipairs(adapters[key].libraries) do
        if libs.get(lib_key) == nil then
            libraries_ok = false
        end
    end
end
check('every adapter library resolves in the libs catalog', libraries_ok, false)

check('blender documents the glTF limit', limits_mention(blender, 'glTF'), false)
check('unity documents no LÖVE runtime interop', limits_mention(unity, 'no LÖVE runtime interop'), false)
check(
    'unreal documents the sandbox validation limit',
    limits_mention(unreal, 'cannot be validated in this sandbox'),
    false
)

local ok_uman, uman_err = unity.validate_interchange_manifest(good_manifest('unity'))
check('unity accepts a well-formed interchange manifest', ok_uman and uman_err == nil, false)

local ok_gman, gman_err = godot.validate_interchange_manifest(good_manifest('godot'))
check('godot accepts a well-formed interchange manifest', ok_gman and gman_err == nil, false)

local ok_bman, bman_err = blender.validate_interchange_manifest({
    format = 'diver-blender-sprites',
    version = blender_config.manifest_version,
    frame_width = 32,
    frame_height = 32,
    strip = 'hero.png',
    frames = { { index = 0, x = 0, y = 0, w = 32, h = 32 } },
})
check('blender accepts a good diver-blender-sprites manifest', ok_bman and bman_err == nil, false)

-- ============ adversarial ============
local function base_case()
    return {
        engine_key = 'case-engine',
        label = 'Case Engine',
        love_version_requirement = '11.5',
        libraries = { 'bump' },
        asset_interchange = {
            capabilities = { 'moves sprites' },
            limits = { 'no runtime interop' },
            runtime_interop = false,
        },
    }
end

local function expect_invalid(name, mod)
    local ok_bad = contract.validate_adapter(mod)
    check(name, not ok_bad, true)
end

-- Each required field removed, one at a time.
local bad1 = base_case()
bad1.engine_key = nil
expect_invalid('removed engine_key rejected', bad1)

local bad2 = base_case()
bad2.label = nil
expect_invalid('removed label rejected', bad2)

local bad3 = base_case()
bad3.love_version_requirement = nil
expect_invalid('removed love_version_requirement rejected', bad3)

local bad4 = base_case()
bad4.libraries = nil
expect_invalid('removed libraries rejected', bad4)

local bad5 = base_case()
bad5.asset_interchange = nil
expect_invalid('removed asset_interchange rejected', bad5)

-- Each required field mistyped, one at a time.
local bad6 = base_case()
bad6.engine_key = 42
expect_invalid('mistyped engine_key rejected', bad6)

local bad7 = base_case()
bad7.label = 42
expect_invalid('mistyped label rejected', bad7)

local bad8 = base_case()
bad8.love_version_requirement = 123
expect_invalid('mistyped love_version_requirement rejected', bad8)

local bad9 = base_case()
bad9.libraries = 'bump'
expect_invalid('mistyped libraries rejected', bad9)

local bad10 = base_case()
bad10.asset_interchange = 'nope'
expect_invalid('mistyped asset_interchange rejected', bad10)

-- Interchange subfields mistyped/emptied, one at a time.
local bad11 = base_case()
bad11.asset_interchange.capabilities = {}
expect_invalid('emptied capabilities rejected', bad11)

local bad12 = base_case()
bad12.asset_interchange.limits = {}
expect_invalid('emptied limits rejected', bad12)

local bad13 = base_case()
bad13.asset_interchange.runtime_interop = 'false'
expect_invalid('mistyped runtime_interop rejected', bad13)

-- Thin-integration rule: unity/unreal/godot must not claim runtime interop.
local bad14 = base_case()
bad14.engine_key = 'unity'
bad14.label = 'Unity'
bad14.asset_interchange.runtime_interop = true
expect_invalid('unity with runtime_interop=true rejected', bad14)

local bad15 = base_case()
bad15.engine_key = 'unreal'
bad15.label = 'Unreal Engine'
bad15.asset_interchange.runtime_interop = true
expect_invalid('unreal with runtime_interop=true rejected', bad15)

local bad16 = base_case()
bad16.engine_key = 'godot'
bad16.label = 'Godot 4'
bad16.asset_interchange.runtime_interop = true
expect_invalid('godot with runtime_interop=true rejected', bad16)

-- Unknown library reference.
local bad17 = base_case()
bad17.libraries = { 'no-such-lib' }
expect_invalid('unknown library rejected', bad17)

-- Malformed interchange manifests rejected (no faked success).
local manifest_bad = 0
local function expect_bad_manifest(mod, manifest)
    local ok_m = mod.validate_interchange_manifest(manifest)
    if not ok_m then
        manifest_bad = manifest_bad + 1
    end
end
expect_bad_manifest(unity, { engine = 'godot', assets = { { path = 'a.png', kind = 'png' } } })
expect_bad_manifest(unity, { engine = 'unity', assets = {} })
expect_bad_manifest(unity, { engine = 'unity', assets = { { path = 'a.png', kind = 'fbx' } } })
expect_bad_manifest(godot, { engine = 'godot', assets = { { path = '../evil.png', kind = 'png' } } })
expect_bad_manifest(blender, { format = 'wrong-format' })
expect_bad_manifest(aseprite, 'not-a-table')
check('malformed interchange manifests rejected (6 cases)', manifest_bad == 6, true)

print(
    ('love2d_adapters: %d/%d passed (%d/%d adversarial)'):format(
        pass_count,
        pass_count + fail_count,
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)
if fail_count > 0 then
    error(('love2d_adapters: %d failures'):format(fail_count))
end
