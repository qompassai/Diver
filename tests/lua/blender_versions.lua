-- Headless test for games/blender version discovery and guards.
-- Runs under headless Neovim nightly with the full diver config:
--   nvim --headless -c "luafile tests/lua/blender_versions.lua" -c "quit!"
-- from the repo root. Pure logic plus the real installed binary;
-- no scene is rendered here (see blender_e2e.lua for that).
--
-- Split: 8 validation checks, 8 adversarial checks
-- (grand total with blender_render_export.lua: 18 validation, 18 adversarial).
local versions = require('games.blender.versions')

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

-- ============ validation ============
local parts = versions.parse_version('5.2.2')
check('parse_version 5.2.2', parts ~= nil and parts[1] == 5 and parts[2] == 2 and parts[3] == 2)

local parts2 = versions.parse_version('4.0.0')
check('parse_version 4.0.0', parts2 ~= nil and parts2[1] == 4 and parts2[2] == 0 and parts2[3] == 0)

check('version_at_least newer', versions.version_at_least({ 5, 2, 2 }, { 4, 0, 0 }))
check('version_at_least equal', versions.version_at_least({ 5, 2, 2 }, { 5, 2, 2 }))
check('version_at_least older patch is false', not versions.version_at_least({ 4, 9, 9 }, { 5, 0, 0 }))

local installed, installed_err = versions.installed_version()
check('installed_version finds 5.2.2', installed == '5.2.2', false, tostring(installed_err))

local version_ok, version_err = versions.check_version()
check('check_version passes against real binary', version_ok, false, tostring(version_err))

local bin, bin_err = versions.ensure_installed()
check('ensure_installed resolves executable', bin ~= nil and vim.fn.executable(bin) == 1, false, tostring(bin_err))

-- ============ adversarial ============
check('parse_version rejects short triple', versions.parse_version('5.2') == nil, true)
check('parse_version rejects v-prefix', versions.parse_version('v5.2.2') == nil, true)
check('parse_version rejects four parts', versions.parse_version('5.2.2.1') == nil, true)
check('parse_version rejects empty', versions.parse_version('') == nil, true)
check('parse_version rejects nil', versions.parse_version(nil) == nil, true)
check('parse_version rejects trailing space', versions.parse_version('5.2.2 ') == nil, true)

local missing, missing_err = versions.installed_version('/nonexistent/blender-xyz')
check('installed_version missing binary fails closed', missing == nil and missing_err ~= nil, true)

local future_ok, future_err = versions.check_version('99.0.0')
check('check_version rejects impossible minimum', not future_ok and future_err ~= nil, true)

print(
    string.format(
        '\nblender_versions: %d passed, %d failed (adversarial %d/%d)',
        pass_count,
        fail_count,
        adversarial_pass,
        adversarial_pass + adversarial_fail
    )
)

if fail_count > 0 then
    vim.cmd('cquit 1')
end
