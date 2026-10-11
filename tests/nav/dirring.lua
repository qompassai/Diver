-- #################################################################
-- /qompassai/diver/tests/nav/dirring.lua
-- Qompass AI Diver directory-ring tests
-- Copyright (C) 2026 Qompass AI, All rights reserved
-- SPDX-License-Identifier: Apache-2.0
-- #################################################################
-- Run from the config root:
--   nvim --headless -u NONE -i NONE -l tests/nav/dirring.lua
--
-- Covers the nav consolidation: the directory ring moved from
-- lua/utils/nav.lua to lua/config/nav/dirring.lua and is wired through
-- config.nav's SUBMODULES. Half validation, half adversarial.
local api, fn = vim.api, vim.fn
local bundle = fn.getcwd()
vim.opt.runtimepath:prepend(bundle)

local failures = 0
local count = 0
local function check(value, label)
    count = count + 1
    if value then
        print('PASS: ' .. label)
    else
        print('FAIL: ' .. label)
        failures = failures + 1
    end
end

-- Silence notifications; capture them for assertions.
local notices = {}
vim.notify = function(msg, _)
    notices[#notices + 1] = msg
end

-- 1. New location loads.
local ok, dirring = pcall(require, 'config.nav.dirring')
check(ok and dirring ~= nil, 'require(config.nav.dirring) loads')

-- 2. Old location is gone (the consolidation actually happened).
local ok_old = pcall(require, 'utils.nav')
check(not ok_old, 'require(utils.nav) fails — old location removed')

if ok then
    -- 3. Setup with persistence disabled (never touches the real ring file).
    dirring.setup({ persist_enabled = false, keymaps_enabled = false })
    local cmds = api.nvim_get_commands({})
    check(cmds['DirPush'] ~= nil, ':DirPush registered')
    check(cmds['DirNext'] ~= nil, ':DirNext registered')
    check(cmds['DirPrev'] ~= nil, ':DirPrev registered')
    check(cmds['DirReset'] ~= nil, ':DirReset registered')
    check(cmds['DirList'] ~= nil, ':DirList registered')

    -- 4. Wired through config.nav SUBMODULES.
    local nav_ok, _ = pcall(require, 'config.nav')
    check(nav_ok, 'require(config.nav) loads')

    -- 5. Ring behavior on real temp dirs.
    local d1 = fn.tempname()
    local d2 = fn.tempname()
    local d3 = fn.tempname()
    fn.mkdir(d1, 'p')
    fn.mkdir(d2, 'p')
    fn.mkdir(d3, 'p')

    dirring.reset()
    check(dirring.size() == 0, 'reset empties the ring')

    local pok = dirring.push(d1)
    check(pok, 'push of existing dir succeeds')
    check(dirring.size() == 1, 'size is 1 after one push')
    check(dirring.current() == d1, 'current is the pushed dir')

    -- 6. Dedupe: pushing the same dir moves the pointer, not the size.
    dirring.push(d2)
    dirring.push(d1)
    check(dirring.size() == 2, 're-push dedupes (size stays 2)')
    check(dirring.current() == d1, 're-push moves pointer to existing entry')

    -- 7. next/prev wraparound (save/restore cwd: they change directory).
    local saved_cwd = fn.getcwd()
    dirring.push(d3) -- ring: d1, d2, d3; current d3
    local nxt = dirring.next()
    check(nxt == d1, 'next wraps from last to first')
    local prv = dirring.prev()
    check(prv == d3, 'prev wraps from first to last')
    vim.cmd('cd ' .. fn.fnameescape(saved_cwd))

    -- 8. jump by index.
    dirring.jump(2)
    check(dirring.current() == d2, 'jump(2) lands on second entry')
    check(dirring.current_index() == 2, 'current_index tracks jump')

    -- 9. Adversarial: push of a non-directory fails cleanly.
    local bad_ok, bad_err = dirring.push('/no/such/dir/xyz123')
    check(bad_ok == false, 'push of missing dir returns false')
    check(type(bad_err) == 'string', 'push of missing dir explains why')
    check(dirring.size() == 3, 'failed push does not grow the ring')

    -- 10. Adversarial: jump out of range does not corrupt state.
    local before = dirring.current()
    dirring.jump(99)
    check(dirring.current() == before, 'out-of-range jump keeps current')

    -- 11. reset clears everything.
    dirring.reset()
    check(dirring.size() == 0 and dirring.current() == nil, 'reset clears ring and current')

    fn.delete(d1, 'rf')
    fn.delete(d2, 'rf')
    fn.delete(d3, 'rf')
end

print(('dirring: %d checks, %d failures'):format(count, failures))
os.exit(failures == 0 and 0 or 1)
