-- Headless test for games.love2d core: versions, package, release, adapters.
-- Runs under headless Neovim nightly with the full diver config:
--   nvim --headless -c "luafile tests/lua/love2d_core.lua" -c "quit!"
-- from the repo root. Pure logic plus the real managed binary for the
-- version probe; no game window opens here (see love2d E2E notes).
--
-- Split: 10 validation checks, 10 adversarial checks
-- (grand total with love2d_libs_dev.lua: 20 validation, 20 adversarial).
local versions = require('games.love2d.versions')
local config = require('games.love2d.config')
local package = require('games.love2d.package')
local release = require('games.love2d.release')
local adapters = require('games.love2d.adapters')

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

local tmpbase = vim.fn.tempname() .. '-love2d-core'

local function write_file(path, text)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    local fh = assert(io.open(path, 'w'))
    fh:write(text)
    fh:close()
end

local function sample_project(name)
    local dir = tmpbase .. '/' .. name
    write_file(dir .. '/main.lua', "function love.draw()\n  love.graphics.print('hi', 10, 10)\nend\n")
    write_file(dir .. '/conf.lua', "function love.conf(t)\n  t.title = 'diver-test'\nend\n")
    write_file(dir .. '/assets/note.txt', 'asset\n')
    return dir
end

local function sha256(path)
    local done = vim.system({ 'sha256sum', path }, { text = true }):wait()
    return (done.stdout or ''):match('^%x+')
end

local function good_adapter()
    return {
        engine_key = 'custom',
        label = 'Custom engine bridge',
        love_version_requirement = '11.5',
        libraries = { 'bump' },
        run_args = { '--console' },
        asset_interchange = {
            capabilities = { 'imports sprite sheets' },
            limits = { 'no animation retargeting' },
            runtime_interop = false,
        },
    }
end

-- ============ validation ============
check('pinned version is 11.5', versions.VERSION == '11.5', false)
check('config.love_version matches versions.VERSION', config.love_version == versions.VERSION, false)

local artifacts_ok = true
for _, key in ipairs({ 'linux', 'win64', 'macos', 'android' }) do
    local a = versions.ARTIFACTS[key]
    if a == nil or type(a.url) ~= 'string' or not a.url:find('11.5', 1, true) then
        artifacts_ok = false
    end
    if a ~= nil and a.sha256 ~= nil and (not a.sha256:match('^%x+$') or #a.sha256 ~= 64) then
        artifacts_ok = false
    end
end
check('artifacts registry: 11.5 URLs, 64-hex digests where recorded', artifacts_ok, false)
check('artifact_path returns nil for unknown key', versions.artifact_path('bogus') == nil, false)
check(
    'entry_is_safe accepts normal paths',
    package.entry_is_safe('main.lua') and package.entry_is_safe('a/b/c.lua'),
    false
)

local proj = sample_project('good')

local ok, verr = package.validate_project(proj, { 'main.lua', 'conf.lua', 'assets/note.txt' }, {})
check('validate_project accepts a good project', ok and verr == nil, false)

local out_love = tmpbase .. '/good.love'
local path, info = package.package(proj, out_love)
check(
    'package() produces a .love',
    path == out_love and type(info) == 'table' and info.entries == 3 and vim.fn.filereadable(out_love) == 1,
    false
)

local out_love2 = tmpbase .. '/good2.love'
local path2 = package.package(proj, out_love2)
check(
    'deterministic packaging: identical tree -> identical bytes',
    path2 ~= nil and sha256(out_love) ~= nil and sha256(out_love) == sha256(out_love2),
    false
)

local ok_adapter, adapter_errors = adapters.validate_adapter(good_adapter())
check('validate_adapter accepts a well-formed adapter', ok_adapter and #adapter_errors == 0, false)

write_file(proj .. '/game.love', 'fake-love-bytes')
local unknown = release.release(proj .. '/game.love', tmpbase .. '/rel', { game = 'g', targets = { 'bogus-os' } })
check(
    'release() reports unknown targets instead of crashing',
    #unknown == 1 and unknown[1].ok == false and unknown[1].err:find('unknown target') ~= nil,
    false
)

-- ============ adversarial ============
local traversal_rejected = true
for _, bad in ipairs({ '../evil.lua', '/abs/path.lua', 'a\\b.lua', '', 'a/../../b.lua' }) do
    if package.entry_is_safe(bad) then
        traversal_rejected = false
    end
end
check('entry_is_safe rejects traversal/absolute/backslash/empty', traversal_rejected, true)

local no_main = sample_project('no-main')
vim.fn.delete(no_main .. '/main.lua')
local ok_nm, err_nm = package.validate_project(no_main, { 'conf.lua' }, {})
check('validate_project rejects a project without main.lua', not ok_nm and err_nm ~= nil, true)

local pkg_nm, pkg_nm_err = package.package(no_main, tmpbase .. '/no-main.love')
check('package() fails closed without main.lua', pkg_nm == nil and pkg_nm_err ~= nil, true)

local big_proj = sample_project('big')
local big_path = big_proj .. '/huge.dat'
local fh = assert(io.open(big_path, 'wb'))
fh:seek('set', 101 * 1024 * 1024) -- sparse: stat sees 101 MiB, disk sees ~0
fh:write('x')
fh:close()
local ok_big, err_big = package.validate_project(big_proj, { 'main.lua', 'conf.lua', 'huge.dat' }, {})
check('validate_project rejects a file over the 100 MiB cap', not ok_big and err_big ~= nil, true)

local link_proj = sample_project('link')
vim.system({ 'ln', '-s', '/etc/hostname', link_proj .. '/sneaky.lua' }):wait()
local link_out = tmpbase .. '/link.love'
local link_path, link_info = package.package(link_proj, link_out)
check(
    'symlinks are skipped, never followed',
    link_path ~= nil and type(link_info) == 'table' and link_info.skipped_symlinks == 1,
    true
)

local tamper = tmpbase .. '/tamper.bin'
write_file(tamper, 'original bytes')
local vok = versions.verify_artifact(tamper, ('0'):rep(64))
check('verify_artifact rejects a checksum mismatch', vok == false, true)

local bad_shapes = 0
local function expect_invalid(mod)
    local ok_bad = adapters.validate_adapter(mod)
    if not ok_bad then
        bad_shapes = bad_shapes + 1
    end
end
expect_invalid('not a table')
local m1 = good_adapter()
m1.engine_key = nil
expect_invalid(m1)
local m2 = good_adapter()
m2.engine_key = 'has space'
expect_invalid(m2)
local m3 = good_adapter()
m3.libraries = { 'no-such-lib' }
expect_invalid(m3)
local m4 = good_adapter()
m4.asset_interchange.limits = {}
expect_invalid(m4)
local m5 = good_adapter()
m5.label = 'Unity thin bridge'
m5.asset_interchange.runtime_interop = true
expect_invalid(m5)
local m6 = good_adapter()
m6.run_args = { 42 }
expect_invalid(m6)
check('validate_adapter rejects 7 malformed shapes', bad_shapes == 7, true)

local ok_name, _ = pcall(release.release, proj .. '/x.love', tmpbase, { game = '../../evil' })
check('release() refuses an unsafe game name', not ok_name, true)

local missing = release.release(tmpbase .. '/does-not-exist.love', tmpbase .. '/rel2', { game = 'g' })
check(
    'release() fails closed on a missing .love',
    #missing == 1 and missing[1].ok == false and missing[1].err:find('no such .love') ~= nil,
    true
)

local pkg_missing, pkg_missing_err = package.package(tmpbase .. '/no-such-dir', tmpbase .. '/x.love')
check('package() fails closed on a missing directory', pkg_missing == nil and pkg_missing_err ~= nil, true)

vim.fn.delete(tmpbase, 'rf')
print(
    ('love2d_core: %d/%d passed (%d/%d adversarial)'):format(
        pass_count,
        pass_count + fail_count,
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)
if fail_count > 0 then
    error(('love2d_core: %d failures'):format(fail_count))
end
