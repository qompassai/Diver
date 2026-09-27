-- tests/lua/dev_apps.lua
-- Balanced suite for the dev.apps generic CLI/TUI launcher: exactly half
-- adversarial and validation (11 checks each, 22 total).
-- Run from the repo root with the FULL config (never -u NONE, never --clean):
--   ~/workspace/tools/neovim-nightly/bin/nvim --headless -i NONE \
--     -u ~/workspace/repos/diver/init.lua -l tests/lua/dev_apps.lua
-- Exit 0 when every check behaves, 1 otherwise. Report goes to
-- $DEV_APPS_REPORT (default /tmp/dev_apps_report.txt).
local report_path = os.getenv('DEV_APPS_REPORT') or '/tmp/dev_apps_report.txt'
local log_lines = {}
local function emit(line)
    log_lines[#log_lines + 1] = line
end
local adv_passed, adv_failed = 0, 0
local val_passed, val_failed = 0, 0
local function adv_check(cond, msg)
    if cond then
        adv_passed = adv_passed + 1
        emit('ok [A] - ' .. msg)
    else
        adv_failed = adv_failed + 1
        emit('NOT OK [A] - ' .. msg)
    end
end
local function val_check(cond, msg)
    if cond then
        val_passed = val_passed + 1
        emit('ok [V] - ' .. msg)
    else
        val_failed = val_failed + 1
        emit('NOT OK [V] - ' .. msg)
    end
end

local apps = require('dev.apps')
apps.setup({
    apps = {
        stub_true = { cmd = { 'true' }, desc = 'test stub' },
        stub_missing = { cmd = { 'devapps-no-such-binary-xyz' }, desc = 'missing binary' },
    },
})

-- Validation ---------------------------------------------------------------
local names = apps.list()
local has_btop, has_lynx = false, false
for _, n in ipairs(names) do
    if n == 'btop' then
        has_btop = true
    elseif n == 'lynx' then
        has_lynx = true
    end
end
val_check(has_btop and has_lynx, 'seeded catalog contains btop and lynx')

local sorted = true
for i = 2, #names do
    if names[i - 1] > names[i] then
        sorted = false
    end
end
val_check(sorted and #names >= 10, 'list() is sorted and includes seeds + stubs')

local info = apps.info('btop')
val_check(info ~= nil and info.desc ~= '' and info.kind == 'float', "info('btop') resolved")

val_check(apps.info('no-such-app') == nil, 'info() of unknown app is nil')

local bufnr = apps.open('stub_true')
val_check(bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr), 'open() launches stub terminal')
val_check(apps.is_open('stub_true'), 'is_open() tracks the launched stub')

local closed = apps.close('stub_true')
val_check(closed >= 1 and not apps.is_open('stub_true'), 'close() shuts the stub terminal')

local bufnr2 = apps.open('stub_true', { args = { '--version' } })
val_check(bufnr2 ~= nil, 'open() accepts override args')
apps.close('stub_true')

-- Adversarial ---------------------------------------------------------------
local b1, e1 = apps.open('')
adv_check(b1 == nil and e1 ~= nil, 'open() rejects empty name')

local b2, e2 = apps.open('no-such-app')
adv_check(b2 == nil and e2 ~= nil and e2:find('no%-such%-app') ~= nil, 'open() names the unknown app')

local b3, e3 = apps.open('stub_missing')
adv_check(b3 == nil and e3 ~= nil and e3:find('not found on PATH') ~= nil, 'open() refuses missing binary')

local ok4 = pcall(apps.setup, { apps = { bad = { cmd = {}, desc = 'x' } } })
adv_check(not ok4, 'setup() rejects empty cmd')

local ok5 = pcall(apps.setup, { apps = { bad = { cmd = { 'true' }, desc = 'x', kind = 'warp' } } })
adv_check(not ok5, 'setup() rejects bad kind')

local ok6 = pcall(apps.setup, { apps = { bad = { cmd = { 'true', 42 }, desc = 'x' } } })
adv_check(not ok6, 'setup() rejects non-string cmd part')

local b7, e7 = apps.open('stub_true', { args = { 42 } })
adv_check(b7 == nil and e7 ~= nil, 'open() rejects non-string override args')

local ok8 = pcall(apps.setup)
adv_check(ok8, 'setup() is idempotent (commands registered once)')

local c9, e9 = apps.close('')
adv_check(c9 == 0 and e9 ~= nil, 'close() rejects empty name')

local b10, e10 = apps.open('stub_true', { kind = 'warp' })
adv_check(b10 == nil and e10 ~= nil, 'open() rejects bad kind override')

local b11, e11 = apps.open('stub_true', { ctx = 'everywhere' })
adv_check(b11 == nil and e11 ~= nil, 'open() rejects bad ctx override')

-- Commands exist (discoverability contract) ----------------------------------
val_check(vim.fn.exists(':Apps') == 2, ':Apps command registered')
val_check(vim.fn.exists(':AppsInfo') == 2, ':AppsInfo command registered')
val_check(vim.fn.exists(':AppsClose') == 2, ':AppsClose command registered')

emit(string.format('adversarial: %d passed, %d failed', adv_passed, adv_failed))
emit(string.format('validation: %d passed, %d failed', val_passed, val_failed))
local f = io.open(report_path, 'w')
f:write(table.concat(log_lines, '\n') .. '\n')
f:close()
os.exit((adv_failed == 0 and val_failed == 0) and 0 or 1)
