-- Headless test for games.love2d libs + dev loop + config shape.
-- Runs under headless Neovim nightly with the full diver config:
--   nvim --headless -c "luafile tests/lua/love2d_libs_dev.lua" -c "quit!"
-- from the repo root. Library tarballs are the real pinned ones from
-- ~/workspace/tools/love2d/11.5/libsrc (offline via artifact_path).
--
-- Split: 10 validation checks, 10 adversarial checks
-- (grand total with love2d_core.lua: 20 validation, 20 adversarial).
local versions = require('games.love2d.versions')
local config = require('games.love2d.config')
local libs = require('games.love2d.libs')
local dev = require('games.love2d.dev')
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

local tmpbase = vim.fn.tempname() .. '-love2d-libs'
vim.fn.mkdir(tmpbase, 'p')

local saved_tools_root = vim.env.LOVE2D_TOOLS_ROOT
vim.env.LOVE2D_TOOLS_ROOT = vim.fn.expand('~/workspace/tools/love2d')

local function real_tarball(key)
    local entry = assert(libs.get(key), 'test setup: unknown catalog key ' .. key)
    local glob = vim.fn.expand('~/workspace/tools/love2d/11.5/libsrc') .. '/' .. key .. '-*.tar.gz'
    local found = vim.fn.glob(glob, false, true)
    assert(#found == 1, 'test setup: pinned tarball missing for ' .. key)
    assert(found[1]:find(entry.pin, 1, true) ~= nil, 'test setup: tarball name lacks the pin')
    return found[1]
end

-- ============ validation ============
check('catalog holds 11 entries', #libs.CATALOG == 11 and #libs.keys() == 11, false)

local catalog_ok, problems = libs.catalog_integrity()
check('catalog_integrity passes', catalog_ok and #problems == 0, false)

local bump = assert(libs.get('bump'), 'test setup: bump missing from catalog')
check('get() returns pinned entries', bump ~= nil and #bump.pin == 40 and libs.get('loveprofiler') ~= nil, false)

local tarball = real_tarball('bump')
local vendored, verr = libs.vendor('bump', tmpbase .. '/vendor', { artifact_path = tarball })
check(
    'vendor() unpacks the pinned tarball after checksum verification',
    vendored ~= nil
        and #vendored == 1
        and vendored[1] == 'bump.lua'
        and vim.fn.filereadable(tmpbase .. '/vendor/bump.lua') == 1
        and verr == nil,
    false
)

local vok, verr2 = libs.verify_artifact(tarball, bump.sha256)
check('verify_artifact accepts the genuine tarball', vok and verr2 == nil, false)

dev.stop()
check('dev.stop() is safe when idle; nothing running', not dev.is_running(), false)

local bin = versions.find_binary()
check(
    'find_binary resolves the managed binary via LOVE2D_TOOLS_ROOT',
    type(bin) == 'string' and bin:find('11.5', 1, true) ~= nil,
    false
)
check('installed_version reports 11.5', versions.installed_version() == '11.5', false)

local groups_ok = true
for _, want in ipairs({ 'Run', 'Develop', 'Package', 'Release', 'Library', 'Setup' }) do
    local found = false
    for _, have in ipairs(config.group_order) do
        if have == want then
            found = true
        end
    end
    if not found then
        groups_ok = false
    end
end
check('config group_order covers the dev loop', groups_ok, false)

local minimal_ok = adapters.validate_adapter({
    engine_key = 'minimal',
    label = 'Minimal',
    love_version_requirement = '>=11.0',
    libraries = {},
    asset_interchange = {
        capabilities = { 'x' },
        limits = { 'y' },
        runtime_interop = false,
    },
})
check('validate_adapter accepts a minimal adapter', minimal_ok, false)

-- ============ adversarial ============
local tampered = tmpbase .. '/bump-tampered.tar.gz'
vim.system({ 'cp', tarball, tampered }):wait()
local fh = assert(io.open(tampered, 'ab'))
fh:write('tamper bytes')
fh:close()
local tvendored, tverr = libs.vendor('bump', tmpbase .. '/tampered-out', { artifact_path = tampered })
check(
    'vendor() refuses a tampered tarball (checksum mismatch)',
    tvendored == nil and tverr ~= nil and tverr:find('checksum mismatch') ~= nil,
    true
)

local uvendored, uverr = libs.vendor('no-such-lib', tmpbase .. '/unknown-out')
check('vendor() rejects an unknown library key', uvendored == nil and uverr ~= nil, true)

local mvok = libs.verify_artifact(tmpbase .. '/no-such-file.tar.gz', bump.sha256)
check('verify_artifact fails closed on a missing file', mvok == false, true)

check('get() returns nil for unknown keys', libs.get('nope') == nil, true)

local run_job = dev.run(tmpbase .. '/no-such-project')
check('dev.run fails closed on a missing project dir', run_job == nil and not dev.is_running(), true)

local wok, werr = dev.watch(tmpbase .. '/no-such-project')
check('dev.watch fails closed on a missing directory', not wok and werr ~= nil, true)

local cok, cerr = dev.setup_console(tmpbase .. '/no-such-project')
check('dev.setup_console fails closed on a missing directory', not cok and cerr ~= nil, true)

-- Deliberately malformed entry: the point of this adversarial check is that
-- catalog_integrity rejects it, so the missing-fields diagnostic is expected
-- here and disabled for this one line only.
---@diagnostic disable-next-line: missing-fields
libs.CATALOG[#libs.CATALOG + 1] = { key = 'bad-injected' }
local bad_ok, bad_problems = libs.catalog_integrity()
libs.CATALOG[#libs.CATALOG] = nil
check(
    'catalog_integrity catches a malformed injected entry',
    not bad_ok and #bad_problems > 0 and #libs.CATALOG == 11,
    true
)

local ok_assert = pcall(libs.verify_artifact, tarball, 'not-hex')
check('verify_artifact asserts on a malformed digest', not ok_assert, true)

local dvendored, dverr = libs.vendor('bump', tmpbase .. '/dir-out', { artifact_path = tmpbase })
check('vendor() rejects a directory as artifact_path', dvendored == nil and dverr ~= nil, true)

vim.env.LOVE2D_TOOLS_ROOT = saved_tools_root
vim.fn.delete(tmpbase, 'rf')
print(
    ('love2d_libs_dev: %d/%d passed (%d/%d adversarial)'):format(
        pass_count,
        pass_count + fail_count,
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)
if fail_count > 0 then
    error(('love2d_libs_dev: %d failures'):format(fail_count))
end
